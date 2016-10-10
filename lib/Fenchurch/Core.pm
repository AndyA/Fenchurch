package Fenchurch::Core;

our $VERSION = "1.00";

use Moose;

use Carp qw( croak );

=head1 NAME

Fenchurch::Core - Fenchurch core modules

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
