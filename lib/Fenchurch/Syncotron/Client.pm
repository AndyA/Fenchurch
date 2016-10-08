package Fenchurch::Syncotron::Client;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Despatcher;
use Fenchurch::Syncotron::State;

with 'Fenchurch::Core::Role::DB', 'Fenchurch::Core::Role::NodeName',
 'Fenchurch::Syncotron::Role::Application',
 'Fenchurch::Syncotron::Role::QueuePair';

has remote_node_name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has state => (
  is      => 'ro',
  isa     => duck_type( ['state'] ),
  lazy    => 1,
  builder => '_b_state',
);

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1
);

=head1 NAME

Fenchurch::Syncotron::Client - The Syncotron Client

=cut

sub _load_state {
  my $self = shift;

  my ($state) = $self->dbh->selectrow_array(
    $self->db->quote_sql(
      "SELECT {state} FROM {:state}",
      " WHERE {local_node} = ? AND {remote_node} = ?"
    ),
    {},
    $self->node_name,
    $self->remote_node_name
  );

  return unless $state;
  return Fenchurch::Syncotron::State->thaw($state);
}

sub save_state {
  my $self = shift;

  $self->dbh->do(
    $self->db->quote_sql(
      "REPLACE INTO {:state}",
      "   ({local_node}, {remote_node}, {updated}, {state})",
      " VALUES (?, ?, NOW(), ?)"
    ),
    {},
    $self->node_name,
    $self->state->freeze
  );
}

sub _b_state {
  my $self = shift;
  return $self->_load_state // Fenchurch::Syncotron::State->new;
}

sub _build_app {
  my ( $self, $de ) = @_;

  my $state = $self->state;

  $de->on(
    'put.info' => sub {
      $state->state('enumerate');
    }
  );

  $de->on(
    'put.leaves' => sub {
      my $msg = shift;
      $state->advance( scalar @{ $msg->{leaves} } );
      #      $state->state('blah') if $msg->{last};
    }
  );
}

sub _receive {
  my $self = shift;
  my $de   = $self->_despatcher;
  for my $ev ( $self->mq_in->take ) {
    $de->despatch($ev);
  }
}

sub _transmit {
  my $self  = shift;
  my $st    = $self->state;
  my $state = $st->state;
  my $mq    = $self->mq_out;

  if ( $state eq 'init' ) {
    $mq->send( { type => 'get.info' } );
  }
  elsif ( $state eq 'enumerate' ) {
    $mq->send(
      { type  => 'get.leaves',
        start => $st->progress
      }
    );
  }
  else {
    die "Unhandled state ", $st->state;
  }
}

sub next {
  my $self = shift;
  $self->_receive;
  $self->_transmit;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
