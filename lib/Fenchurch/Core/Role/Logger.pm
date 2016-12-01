package Fenchurch::Core::Role::Logger;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;
use Log::Log4perl;

=head1 NAME

Fenchurch::Core::Role::Logger - Log4perl based logging

=cut

has 'log' => ( is => 'rw', lazy => 1, builder => '_b_log' );

sub _b_log { Log::Log4perl->get_logger( ref $_[0] ) }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
