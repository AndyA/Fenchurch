package Fenchurch::Syncotron::Fault;

our $VERSION = "1.00";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

has location => (
  is       => 'ro',
  isa      => enum( ['local', 'remote'] ),
  required => 1
);

has error => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

with Storage( format => 'JSON' );

=head1 NAME

Fenchurch::Syncotron::Fault - A fault description

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
