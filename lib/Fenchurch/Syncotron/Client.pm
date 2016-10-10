package Fenchurch::Syncotron::Client;

our $VERSION = "1.00";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Despatcher;

has remote_node_name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has page_size => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 10_000
);

with
 'Fenchurch::Core::Role::NodeName',
 'Fenchurch::Event::Role::Emitter',
 'Fenchurch::Syncotron::Role::Versions',
 'Fenchurch::Syncotron::Role::Engine',
 'Fenchurch::Syncotron::Role::QueuePair',
 'Fenchurch::Syncotron::Role::Application',
 'Fenchurch::Syncotron::Role::Stateful';

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
      my $msg    = shift;
      my @leaves = @{ $msg->{leaves} };
      $self->_get_versions( $eng->dont_have(@leaves) );
      $state->serial( $msg->{serial} );
      $state->advance( scalar @leaves );
      $state->state('recent') if $msg->{last};
    }
  );

  $de->on(
    'put.recent' => sub {
      my $msg    = shift;
      my @recent = @{ $msg->{recent} };
      $self->_get_versions( $eng->dont_have(@recent) );
      $state->serial( $msg->{serial} );
    }
  );

  $de->on(
    'put.versions' => sub {
      my $msg = shift;
      $self->engine->add_versions( @{ $msg->{versions} } );
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
  $self->_receive;
  $self->_transmit;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
