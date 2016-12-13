package Fenchurch::Core::UUIDFactory;

our $VERSION = "1.00";

use v5.10;

use Moose;

use UUID::Tiny ();

=head1 NAME

Fenchurch::Core::UUIDFactory - A factory for UUIDs

=cut

sub make_uuid { UUID::Tiny::create_uuid_as_string(UUID::Tiny::UUID_V4) }

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
