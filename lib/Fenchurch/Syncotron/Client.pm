package Fenchurch::Syncotron::Client;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Despatcher;

sub node_name;

has remote_node_name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1
);

with 'Fenchurch::Core::Role::DB',
 'Fenchurch::Core::Role::NodeName',
 'Fenchurch::Syncotron::Role::Application',
 'Fenchurch::Syncotron::Role::QueuePair',
 'Fenchurch::Syncotron::Role::Stateful';

=head1 NAME

Fenchurch::Syncotron::Client - The Syncotron Client

=cut

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
