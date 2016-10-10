package Fenchurch::Syncotron::Role::QueuePair;

our $VERSION = "1.00";

use Moose::Role;
use Moose::Util::TypeConstraints;

=head1 NAME

Fenchurch::Syncotron::Role::QueuePair - A send / receive message queue pair

=cut

sub mq_in;
sub mq_out;

has ['mq_in', 'mq_out'] => (
  is       => 'ro',
  isa      => duck_type( ['send', 'peek', 'take', 'with_messages'] ),
  required => 1
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
