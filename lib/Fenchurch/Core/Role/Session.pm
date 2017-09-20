package Fenchurch::Core::Role::Session;

our $VERSION = "0.01";

use Fenchurch::Module;
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

has session_unknown => (
  is      => 'ro',
  isa     => 'Str',
  default => "UNKNOWN"
);

sub _b_session {
  my $self = shift;
  return $ENV{FENCHURCH_SESSION} // $self->session_unknown;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
