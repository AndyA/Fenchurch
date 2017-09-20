package Fenchurch::Adhocument::Sanity::Role::Report;

our $VERSION = "0.01";

use Fenchurch::Module;
use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Adhocument::Sanity::Report;

=head1 NAME

Fenchurch::Adhocument::Sanity::Role::Report - Add a report

=cut

has report => (
  is      => 'ro',
  isa     => duck_type( ["log"] ),
  lazy    => 1,
  builder => '_b_report',
  handles => ['log']
);

sub _b_report { Fenchurch::Adhocument::Sanity::Report->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
