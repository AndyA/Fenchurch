package Fenchurch::Syncotron::Client;

our $VERSION = "1.00";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Despatcher;
use Fenchurch::Syncotron::Fault;
use Try::Tiny;

has remote_node_name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has page_size => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 100
);

with qw(
 Fenchurch::Core::Role::NodeName
 Fenchurch::Syncotron::Role::Versions
 Fenchurch::Syncotron::Role::Engine
 Fenchurch::Syncotron::Role::Application
 Fenchurch::Syncotron::Role::Stateful
);

=head1 NAME

Fenchurch::Syncotron::Client - The Syncotron Client

=cut

sub _get_versions {
  my ( $self, @uuid ) = @_;

  return unless @uuid;

  $self->_send(
    { type => 'get.versions',
      uuid => \@uuid
    }
  );
}

sub _update_serial {
  my ( $self, $msg ) = @_;

  # If the serial number goes backwards that implies
  # that the node has been reset.
  if ( $msg->{serial} < $self->state->serial ) {
    $self->clear_state;
    return 0;
  }

  $self->state->serial( $msg->{serial} );
  return 1;
}

sub _build_app {
  my ( $self, $de ) = @_;

  $de->on(
    'put.info' => sub {
      $self->state->state('enumerate');
    }
  );

  $de->on(
    'put.leaves' => sub {
      my $msg    = shift;
      my @leaves = @{ $msg->{leaves} };
      $self->engine->known(@leaves);
      return unless $self->_update_serial($msg);
      $self->state->advance( scalar @leaves );
      $self->state->state('recent') if $msg->{last};
    }
  );

  $de->on(
    'put.recent' => sub {
      my $msg = shift;
      $self->engine->known( @{ $msg->{recent} } );
      $self->_update_serial($msg);
    }
  );

  $de->on(
    'put.versions' => sub {
      my $msg = shift;
      $self->engine->add_versions( @{ $msg->{versions} } );
    }
  );

  $de->on(
    'put.error' => sub {
      my $msg = shift;
      $self->state->fault(
        Fenchurch::Syncotron::Fault->new(
          error    => $msg->{error},
          location => 'remote'
        )
      );
    }
  );
}

sub _receive {
  my $self = shift;
  for my $ev ( $self->mq_in->take ) {
    $self->_despatch($ev);
  }
}

sub _transmit {
  my $self  = shift;
  my $state = $self->state->state;

  if ( $state eq 'init' ) {
    $self->_send( { type => 'get.info' } );
  }
  elsif ( $state eq 'enumerate' ) {
    $self->_send(
      { type  => 'get.leaves',
        start => $self->state->progress
      }
    );
  }
  elsif ( $state eq 'recent' ) {
    $self->_send(
      { type   => 'get.recent',
        serial => $self->state->serial
      }
    );
  }
  else {
    die "Unhandled state ", $state;
  }

  $self->_get_versions( $self->engine->want( 0, $self->page_size ) );
}

sub next {
  my $self = shift;

  if ( $self->state->state eq 'fault' ) {
    my $fault = $self->state->fault;
    die "Can't continue in faulted state (location: ", $fault->location,
     ", error: ", $fault->error, ")";
  }

  try {
    $self->_receive;
    $self->_transmit;
  }
  catch {
    $self->state->fault(
      Fenchurch::Syncotron::Fault->new(
        error    => $_,
        location => 'local'
      )
     )
  };
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
