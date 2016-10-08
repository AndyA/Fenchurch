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

with 'Fenchurch::Core::Role::DB',
 'Fenchurch::Core::Role::NodeName',
 'Fenchurch::Syncotron::Role::Application',
 'Fenchurch::Syncotron::Role::Engine',
 'Fenchurch::Syncotron::Role::QueuePair';

=head1 NAME

Fenchurch::Syncotron::Server - The Syncotron Server

=cut

sub _put_leaves {
  my ( $self, $start ) = @_;

  my $mq  = $self->mq_out;
  my $eng = $self->engine;

  my $chunk  = $self->page_size;
  my $serial = $eng->serial;
  my @leaves = $eng->leaves( $start, $chunk );
  my $last   = @leaves < $chunk ? 1 : 0;

  # Stuff the last page of results with a random sample
  # if it's not full
  push @leaves, $eng->sample( 0, $chunk - @leaves )
   if $last && $start == 0;

  $mq->send(
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
  $self->mq_out->send( { type => 'put.versions', versions => $ver } );
}

sub _put_recent {
  my ( $self, $serial ) = @_;
  my $recent = $self->engine->recent( $serial, $self->page_size );
  $self->mq_out->send( { type => 'put.recent', %$recent } );
}

sub _build_app {
  my ( $self, $de ) = @_;

  my $mq = $self->mq_out;

  $de->on(
    'get.info' => sub {
      $mq->send(
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
  my $de   = $self->_despatcher;
  for my $ev ( $self->mq_in->take ) {
    $de->despatch($ev);
  }
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
