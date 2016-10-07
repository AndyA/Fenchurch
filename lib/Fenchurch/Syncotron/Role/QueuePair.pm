package Fenchurch::Syncotron::Role::QueuePair;

our $VERSION = "0.01";

use Moose::Role;
use Moose::Util::TypeConstraints;

=head1 NAME

Fenchurch::Syncotron::Role::QueuePair - A send / receive message queue pair

=cut

has ['mq_in', 'mq_out'] => (
  is       => 'ro',
  isa      => duck_type( ['send', 'peek', 'take', 'with_messages'] ),
  required => 1
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
