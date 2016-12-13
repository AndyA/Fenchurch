package Fenchurch::Core::Role::UUIDFactory;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;

use UUID::Tiny ();

=head1 NAME

Fenchurch::Core::Role::UUIDFactory - Create new UUIDs

=cut

sub make_uuid { UUID::Tiny::create_uuid_as_string(UUID::Tiny::UUID_V4) }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
