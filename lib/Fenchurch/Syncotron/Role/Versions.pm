package Fenchurch::Syncotron::Role::Versions;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;
use Moose::Util::TypeConstraints;

sub db;
sub dbh;
sub versions;

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1,
  handles => ['db', 'dbh'],
);

=head1 NAME

Fenchurch::Syncotron::Role::Versions - A versions attribute

=cut

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
