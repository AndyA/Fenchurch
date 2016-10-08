package Fenchurch::Syncotron::Engine;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1,
  handles => ['db', 'dbh'],
);

=head1 NAME

Fenchurch::Syncotron::Engine - The guts of the sync engine

=cut

sub leaves {
}

sub sample {
}

sub since {
}

sub serial {
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
