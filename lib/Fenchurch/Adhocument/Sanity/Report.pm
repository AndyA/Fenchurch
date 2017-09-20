package Fenchurch::Adhocument::Sanity::Report;

our $VERSION = "0.01";

use Fenchurch::Moose;

=head1 NAME

Fenchurch::Adhocument::Sanity::Report - Gather data for Sanity report

=cut

has _log => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub { [] },
  handles => {
    log     => 'push',
    get_log => 'elements',
  }
);

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
