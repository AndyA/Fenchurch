package Fenchurch::Core::Role::Lock;

our $VERSION = "0.01";

use v5.10;

use Moose::Role;

use Fenchurch::Core::Lock;

=head1 NAME

Fenchurch::Core::Role::Lock - Add a lock

=cut

requires 'db';

sub lock {
  my ( $self, @args ) = @_;
  return Fenchurch::Core::Lock->new( db => $self->db, @args );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
