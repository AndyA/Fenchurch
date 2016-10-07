package Fenchurch::Syncotron::Server;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

with 'Fenchurch::Core::Role::DB', 'Fenchurch::Core::Role::NodeName',
 'Fenchurch::Syncotron::Role::Application',
 'Fenchurch::Syncotron::Role::QueuePair';

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

=head1 NAME

Fenchurch::Syncotron::Server - The Syncotron Server

=cut

sub _put_leaves {
  my ( $self, $start ) = @_;

  my $mq = $self->mq_out;
  my $ve = $self->versions;

  my $chunk  = $self->page_size;
  my $serial = $ve->serial;
  my @leaves = $ve->leaves( $start, $chunk );
  my $last   = @leaves < $chunk ? 1 : 0;

  # Stuff the last page of results with a random sample
  # if it's not full
  push @leaves, $ve->sample( 0, $chunk - @leaves )
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

sub _build_app {
  my ( $self, $de ) = @_;

  my $mq = $self->mq_out;
  my $ve = $self->versions;

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
