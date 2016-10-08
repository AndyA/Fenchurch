package Fenchurch::Syncotron::Role::Engine;

our $VERSION = "0.01";

use Moose::Role;
use Moose::Util::TypeConstraints;

has engine => (
  is      => 'ro',
  isa     => duck_type( ['leaves', 'since', 'serial', 'sample'] ),
  lazy    => 1,
  builder => '_b_engine',
);

requires 'versions';

=head1 NAME

Fenchurch::Syncotron::Role::Engine - Add a Syncotron engine

=cut

sub _b_engine {
  my $self = shift;
  return Fenchurch::Syncotron::Engine->new( versions => $self->versions );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
