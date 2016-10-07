package Fenchurch::Syncotron::State;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with Storage( format => 'JSON' );

=head1 NAME

Fenchurch::Syncotron::State - Sync state

=cut

has state => (
  is      => 'rw',
  isa     => enum( ['init', 'leaves'] ),
  default => 'init'
);

has ['progress', 'serial'] => (
  is      => 'rw',
  isa     => 'Int',
  default => 0
);

after state => sub {
  my $self = shift;
  $self->progress(0) if @_;

};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl