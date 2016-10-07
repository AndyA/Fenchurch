package Fenchurch::Syncotron::Client;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Despatcher;
use Fenchurch::Syncotron::State;

with 'Fenchurch::Core::Role::DB';
with 'Fenchurch::Core::Role::NodeName';
with 'Fenchurch::Syncotron::Role::Application';
with 'Fenchurch::Syncotron::Role::QueuePair';

has table => (
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

=head1 NAME

Fenchurch::Syncotron::Client - The Syncotron Client

=cut

sub _load_state {
  my $self = shift;

  my $table = $self->db->quote_name( $self->table );

  my ($state)
   = $self->dbh->selectrow_array(
    $self->db->quote_sql("SELECT {state} FROM $table WHERE {node} = ?"),
    {}, $self->node_name );

  return unless $state;
  return Fenchurch::Syncotron::State->thaw($state);
}

sub save_state {
  my $self = shift;

  my $table = $self->db->quote_name( $self->table );
  $self->dbh->do(
    $self->db->quote_sql(
      "REPLACE INTO $table ({node}, {state}) VALUES (?, ?)"),
    {},
    $self->node_name,
    $self->state->freeze
  );
}

sub _b_state {
  my $self = shift;
  return $self->_load_state // Fenchurch::Syncotron::State->new;
}

sub _receive {
  my $self = shift;
  my $de   = $self->_despatcher;
  for my $ev ( $self->mq_in->take ) {
    $de->despatch($ev);
  }
}

sub _transmit {
  my $self = shift;
  my $st   = $self->state;
  my $mq   = $self->mq_out;

  if ( $st->state eq 'init' ) {
    $mq->send( { type => 'info' } );
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
