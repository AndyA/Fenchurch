package Fenchurch::Adhocument::Role::Schema;

our $VERSION = "1.00";

use Fenchurch::Module;
use Moose::Role;

use Fenchurch::Adhocument::Schema;

=head1 NAME

Fenchurch::Adhocument::Role::Schema - Add a schema

=cut

has schema => (
  is       => 'ro',
  required => 1,
  isa      => 'Fenchurch::Adhocument::Schema',
  handles =>
   ['spec_for', 'spec_for_root', 'pkey_for', 'table_for', 'tables_for']
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
