package Fenchurch::Syncotron::Server;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;

with 'Fenchurch::Core::Role::DB';
with 'Fenchurch::Core::Role::NodeName';
with 'Fenchurch::Syncotron::Role::Application';
with 'Fenchurch::Syncotron::Role::QueuePair';

=head1 NAME

Fenchurch::Syncotron::Server - The Syncotron Server

=cut

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
