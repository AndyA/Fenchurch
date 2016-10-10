package Fenchurch::Core::Role::NodeName;

our $VERSION = "1.00";

use Moose::Role;

use Sys::Hostname;

=head1 NAME

Fenchurch::Core::Role::NodeName - The name of this node

=cut

sub node_name;
has node_name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  lazy     => 1,
  builder  => '_b_node_name'
);

sub _b_node_name { hostname }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
