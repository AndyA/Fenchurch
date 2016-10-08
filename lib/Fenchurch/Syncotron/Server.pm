package Fenchurch::Syncotron::Server;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Engine;

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1
);

has page_size => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 10_000
);

sub mq_out;
sub emit;
with 'Fenchurch::Core::Role::DB',
 'Fenchurch::Core::Role::NodeName',
 'Fenchurch::Event::Role::Emitter',
 'Fenchurch::Syncotron::Role::Engine',
 'Fenchurch::Syncotron::Role::QueuePair',
 'Fenchurch::Syncotron::Role::Application';

=head1 NAME

Fenchurch::Syncotron::Server - The Syncotron Server

=cut

sub _put_leaves {
  my ( $self, $start ) = @_;

  my $eng = $self->engine;

  my $chunk  = $self->page_size;
  my $serial = $eng->serial;
  my @leaves = $eng->leaves( $start, $chunk );
  my $last   = @leaves < $chunk ? 1 : 0;

  # Stuff the last page of results with a random sample
  # if it's not full
  push @leaves, $eng->sample( 0, $chunk - @leaves )
   if $last && $start == 0;

  $self->_send(
    { type   => 'put.leaves',
      start  => $start,
      last   => $last,
      leaves => \@leaves,
      serial => $serial
    }
  );
}

sub _put_versions {
  my ( $self, @uuid ) = @_;
  my $ver = $self->versions->load_versions(@uuid);
  $self->_send( { type => 'put.versions', versions => $ver } );
}

sub _put_recent {
  my ( $self, $serial ) = @_;
  my $recent = $self->engine->recent( $serial, $self->page_size );
  $self->_send( { type => 'put.recent', %$recent } );
}

sub _build_app {
  my ( $self, $de ) = @_;

  $de->on(
    'get.info' => sub {
      $self->_send(
        { type => 'put.info',
          info => { node => $self->node_name },
        }
      );
    }
  );

  $de->on(
    'get.leaves' => sub {
      my $msg = shift;
      $self->_put_leaves( $msg->{start} );
    }
  );

  $de->on(
    'get.recent' => sub {
      my $msg = shift;
      $self->_put_recent( $msg->{serial} );
    }
  );

  $de->on(
    'get.versions' => sub {
      my $msg = shift;
      $self->_put_versions( @{ $msg->{uuid} } );
    }
  );
}

sub next {
  my $self = shift;
  for my $ev ( $self->mq_in->take ) {
    $self->_despatch($ev);
  }
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
