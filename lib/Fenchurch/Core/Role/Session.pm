package Fenchurch::Core::Role::Session;

our $VERSION = "0.01";

use v5.10;

use Moose::Role;

=head1 NAME

Fenchurch::Core::Role::Session - Get a token for the current uptime session

=cut

has session => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  builder => '_b_session'
);

sub _b_session {
  my $self = shift;
  return $ENV{FENCHURCH_SESSION} // "UNKNOWN";
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
