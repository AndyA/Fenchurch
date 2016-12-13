package Fenchurch::Adhocument::Role::Options;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;

=head1 NAME

Fenchurch::Adhocument::Role::Options - Common options

=cut

has ['numify', 'ignore_extra_columns'] => (
  is       => 'ro',
  isa      => 'Bool',
  required => 1,
  default  => 0
);

sub _options {
  my $self = shift;
  return map { $_ => $self->$_() } qw( numify ignore_extra_columns );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
