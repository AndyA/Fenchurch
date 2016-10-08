package Fenchurch::Core::Role::DB;

our $VERSION = "1.00";

use Moose::Role;
use MooseX::Storage;

use Fenchurch::Core::DB;

=head1 NAME

Fenchurch::Core::Role::DB - A database connection 

=cut

has db => (
  is       => 'ro',
  isa      => 'Fenchurch::Core::DB',
  required => 1,
  traits   => ['DoNotSerialize'],
  handles  => ['dbh', 'transaction']
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
