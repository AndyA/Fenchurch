package Fenchurch::Adhocument::Role::Options;

our $VERSION = "1.00";

use Fenchurch::Module;
use Moose::Role;

=head1 NAME

Fenchurch::Adhocument::Role::Options - Common options

=cut

my @OPTIONS = qw(
 numify ignore_extra_columns write_auto
);

has [@OPTIONS] => (
  is       => 'ro',
  isa      => 'Bool',
  required => 1,
  default  => 0
);

sub _options {
  my $self = shift;
  return map { $_ => $self->$_() } @OPTIONS;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
