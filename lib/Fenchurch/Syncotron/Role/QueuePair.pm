package Fenchurch::Syncotron::Role::QueuePair;

our $VERSION = "1.00";

use Fenchurch::Module;
use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::MessageQueue;

=head1 NAME

Fenchurch::Syncotron::Role::QueuePair - A send / receive message queue pair

=cut

sub mq_in;
sub mq_out;

has ['mq_in', 'mq_out'] => (
  is      => 'ro',
  isa     => duck_type( ['send', 'peek', 'take', 'with_messages'] ),
  lazy    => 1,
  builder => '_b_mq'
);

sub _b_mq { Fenchurch::Syncotron::MessageQueue->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
