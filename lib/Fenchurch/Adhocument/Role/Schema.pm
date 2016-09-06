package Fenchurch::Adhocument::Role::Schema;

use Moose::Role;

use Fenchurch::Adhocument::Schema;

=head1 NAME

Fenchurch::Adhocument::Role::Schema - Add a schema

=cut

has schema => (
  is       => 'ro',
  required => 1,
  isa      => 'Fenchurch::Adhocument::Schema',
  handles  => ['schema_for', 'spec_for', 'spec_for_root', 'pkey_for']
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
