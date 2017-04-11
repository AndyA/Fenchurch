package Fenchurch::Syncotron::Client;

our $VERSION = "1.00";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Despatcher;
use Fenchurch::Syncotron::Fault;
use Fenchurch::Syncotron::Ping;
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
  default  => 10_000
);

has ping_interval => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 10
);

has ping_jitter => (
  is       => 'ro',
  isa      => 'Num',
  required => 1,
  default  => 1
);

with qw(
 Fenchurch::Core::Role::Logger
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
    $self->log->info( "Serial went from ",
      $self->state->serial, " to ", $msg->{serial}, ", clearing state" );
    $self->clear_state;
    return 0;
  }

  $self->log->debug( "Setting serial to ", $msg->{serial} );

  $self->state->serial( $msg->{serial} );
  return 1;
}

sub _build_app {
  my ( $self, $de ) = @_;

  $de->on(
    'put.info' => sub {
      my $msg = shift;
      $self->_update_serial($msg);
      $self->state->state('enumerate');
    }
  );

  $de->on(
    'put.leaves' => sub {
      my $msg    = shift;
      my @leaves = @{ $msg->{leaves} };
      $self->engine->known(@leaves);
      $self->state->advance( scalar @leaves );
      $self->state->state('sample') if $msg->{last};
    }
  );

  $de->on(
    'put.sample' => sub {
      my $msg    = shift;
      my @sample = @{ $msg->{sample} };
      $self->engine->known(@sample);
      $self->state->advance( scalar @sample );
      $self->state->state('recent')
       if $msg->{last}
       || $self->state->progress >= $self->state->hwm;
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

  $de->on(
    'put.*' => sub {
      $self->engine->flush_pending(5);
    }
  );
}

sub _receive {
  my $self = shift;
  for my $ev ( $self->mq_in->take ) {
    $self->_despatch($ev);
  }
}

sub _send_messages {
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
  elsif ( $state eq 'sample' ) {
    $self->_send(
      { type  => 'get.sample',
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
}

sub _send_pings {
  my $self = shift;

  my $p = $self->ping;

  if ( $p->need_new_ping( $self->ping_interval ) ) {
    $p->put(
      $p->make_ping(
        status => {
          states     => $self->load_all_states,
          statistics => $self->engine->statistics
        }
      )
    );
  }

  my @pings = $p->get_for_remote( $self->remote_node_name );

  $self->_send(
    { type   => 'put.pings',
      serial => $self->state->serial,
      pings  => \@pings
    }
  );
}

sub _transmit {
  my $self = shift;

  $self->_send_messages;
  $self->_get_versions( $self->engine->want( 0, $self->page_size ) );
}

sub _pings {
  my $self = shift;

  my $now = time;
  if ( $now > $self->state->next_ping ) {
    $self->_send_pings;
    my $interval = $self->ping_interval;
    $self->state->next_ping(
      $now + $interval + $self->ping_jitter * $interval * ( rand() - 0.5 ) );
  }
}

sub next {
  my $self = shift;

  try {
    if ( $self->state->state ne 'fault' ) {
      $self->_receive;
      $self->_transmit;
    }
    $self->_pings;
  }
  catch {
    $self->state->fault(
      Fenchurch::Syncotron::Fault->new(
        error    => "$_",
        location => 'local'
      )
     )
  };
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
