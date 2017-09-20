package Fenchurch::Core::Role::Logger;

our $VERSION = "1.00";

use Fenchurch::Module;
use Moose::Role;
use MooseX::Storage;
use Log::Log4perl;

=head1 NAME

Fenchurch::Core::Role::Logger - Log4perl based logging

=cut

sub log;
has 'log' => (
  is      => 'rw',
  lazy    => 1,
  builder => '_b_log',
  traits  => ['DoNotSerialize'],
);

sub _b_log { Log::Log4perl->get_logger( ref $_[0] || $_[0] ) }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
