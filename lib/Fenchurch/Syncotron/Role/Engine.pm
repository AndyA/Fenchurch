package Fenchurch::Syncotron::Role::Engine;

our $VERSION = "1.00";

use Fenchurch::Module;
use Moose::Role;
use Moose::Util::TypeConstraints;

has engine => (
  is      => 'ro',
  isa     => duck_type( ['leaves', 'since', 'serial', 'sample'] ),
  lazy    => 1,
  builder => '_b_engine',
);

has ping => (
  is      => 'ro',
  isa     => 'Fenchurch::Syncotron::Ping',
  lazy    => 1,
  builder => '_b_ping'
);

requires 'versions';

=head1 NAME

Fenchurch::Syncotron::Role::Engine - Add a Syncotron engine

=cut

sub _b_engine {
  my $self = shift;
  return Fenchurch::Syncotron::Engine->new( versions => $self->versions );
}

sub _b_ping {
  my $self = shift;
  return Fenchurch::Syncotron::Ping->new(
    engine => $self->versions->unversioned );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
