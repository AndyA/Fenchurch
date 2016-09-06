package Lintilla::Core::Role::DB;

use Moose::Role;

use Lintilla::Core::DB;

=head1 NAME

Lintilla::Core::Role::DB - A database connection 

=cut

has db => (
  is       => 'ro',
  isa      => 'Lintilla::Core::DB',
  required => 1,
  handles  => ['dbh']
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
