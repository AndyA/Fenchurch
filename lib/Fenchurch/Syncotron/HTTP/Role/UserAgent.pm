package Fenchurch::Syncotron::HTTP::Role::UserAgent;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;
use Moose::Util::TypeConstraints;

use LWP::UserAgent;

has _ua => (
  is      => 'ro',
  isa     => duck_type( ['request'] ),
  lazy    => 1,
  builder => '_b_ua'
);

=head1 NAME

Fenchurch::Syncotron::HTTP::Role::UserAgent - Add an LWP::UserAgent

=cut

sub _b_ua { LWP::UserAgent->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
