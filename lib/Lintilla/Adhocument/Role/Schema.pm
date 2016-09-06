package Lintilla::Adhocument::Role::Schema;

use Moose::Role;

use Lintilla::Adhocument::Schema;

=head1 NAME

Lintilla::Adhocument::Role::Schema - Add a schema

=cut

has schema => (
  is       => 'ro',
  required => 1,
  isa      => 'Lintilla::Adhocument::Schema',
  handles  => ['schema_for', 'spec_for', 'spec_for_root', 'pkey_for']
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
