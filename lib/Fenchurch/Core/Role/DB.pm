package Fenchurch::Core::Role::DB;

our $VERSION = "0.01";

use Moose::Role;

use Fenchurch::Core::DB;

=head1 NAME

Fenchurch::Core::Role::DB - A database connection 

=cut

has db => (
  is       => 'ro',
  isa      => 'Fenchurch::Core::DB',
  required => 1,
  handles  => ['dbh', 'transaction']
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
