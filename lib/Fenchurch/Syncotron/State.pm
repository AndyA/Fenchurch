package Fenchurch::Syncotron::State;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

=head1 NAME

Fenchurch::Syncotron::State - Sync state

=cut

has state => (
  is      => 'rw',
  isa     => enum( ['init', 'enumerate', 'recent'] ),
  default => 'init'
);

has ['progress', 'serial'] => (
  is      => 'rw',
  isa     => 'Int',
  default => 0
);

with Storage( format => 'JSON' );

after state => sub {
  my $self = shift;
  $self->progress(0) if @_;

};

sub advance {
  my ( $self, $amount ) = @_;
  $self->progress( $self->progress + $amount );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
