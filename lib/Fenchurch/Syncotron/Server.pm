package Fenchurch::Syncotron::Server;

our $VERSION = "1.00";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Engine;
use Try::Tiny;
use List::Util qw( shuffle );

has page_size => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 10_000
);

# Tuning: approx size of an edit
has edit_size => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 10_000
);

# Maximum size of a put.versions message.
has max_size => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 1000_000
);

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::NodeName
 Fenchurch::Syncotron::Role::Versions
 Fenchurch::Syncotron::Role::Engine
 Fenchurch::Syncotron::Role::Application
);

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

sub _put_sample {
  my ( $self, $start ) = @_;

  my $eng = $self->engine;

  my $chunk  = $self->page_size;
  my $serial = $eng->serial;
  my @sample = $eng->sample( $start, $chunk );
  my $last   = @sample < $chunk ? 1 : 0;

  $self->_send(
    { type   => 'put.sample',
      start  => $start,
      last   => $last,
      sample => \@sample,
      serial => $serial
    }
  );
}

sub _put_versions {
  my ( $self, @uuid ) = @_;

  @uuid = shuffle @uuid;

  while (@uuid) {
    my @chunk = splice @uuid, 0, 25;
    my @ver = grep { defined } @{ $self->versions->load_versions(@chunk) };
    while (@ver) {
      $self->_send( { type => 'put.versions', versions => [shift @ver] } );
      if ( $self->mq_out->size > $self->max_size ) {
        $self->mq_out->unsend(1);
        return;
      }
    }
  }
}

sub _put_recent {
  my ( $self, $serial ) = @_;
  my $recent = $self->engine->recent( $serial, $self->page_size );
  $self->_send( { type => 'put.recent', %$recent } );
}

sub _put_error {
  my ( $self, $error ) = @_;
  $self->_send( { type => 'put.error', error => $error } );
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
    'get.sample' => sub {
      my $msg = shift;
      $self->_put_sample( $msg->{start} );
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
  try {
    for my $ev ( $self->mq_in->take ) {
      $self->_despatch($ev);
    }
  }
  catch {
    my $error = $_;
    $self->_put_error($error);
  };
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
