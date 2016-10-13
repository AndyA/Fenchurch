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
  default  => 1000
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

sub _build_app {
  my ( $self, $de ) = @_;

  my $state = $self->state;
  my $eng   = $self->engine;

  $de->on(
    'put.info' => sub {
      $state->state('enumerate');
    }
  );

  $de->on(
    'put.leaves' => sub {
      my $msg = shift;

      my @leaves = @{ $msg->{leaves} };
      $eng->known(@leaves);
      $state->serial( $msg->{serial} );
      $state->advance( scalar @leaves );
      $state->state('recent') if $msg->{last};
    }
  );

  $de->on(
    'put.recent' => sub {
      my $msg = shift;

      $eng->known( @{ $msg->{recent} } );
      $state->serial( $msg->{serial} );
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
      $state->fault(
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
  my $st    = $self->state;
  my $state = $st->state;

  if ( $state eq 'init' ) {
    $self->_send( { type => 'get.info' } );
  }
  elsif ( $state eq 'enumerate' ) {
    $self->_send(
      { type  => 'get.leaves',
        start => $st->progress
      }
    );
  }
  elsif ( $state eq 'recent' ) {
    $self->_send(
      { type   => 'get.recent',
        serial => $st->serial
      }
    );
  }
  else {
    die "Unhandled state ", $st->state;
  }

  $self->_get_versions( $self->engine->want( 0, $self->page_size ) );
}

sub next {
  my $self = shift;

  my $st = $self->state;

  if ( $st->state eq 'fault' ) {
    my $fault = $st->fault;
    die "Can't continue in faulted state (location: ", $fault->location,
     ", error: ", $fault->error, ")";
  }

  try {
    $self->_receive;
    $self->_transmit;
  }
  catch {
    $st->fault(
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
