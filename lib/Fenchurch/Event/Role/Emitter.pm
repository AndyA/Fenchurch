package Fenchurch::Event::Role::Emitter;

use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Event::Emitter;

=head1 NAME

Fenchurch::Event::Role::Emitter - Be an event emitter

=cut

has emitter => (
  is       => 'ro',
  required => 1,
  isa      => duck_type( [Fenchurch::Event::Emitter->interface] ),
  handles  => [Fenchurch::Event::Emitter->interface],
  builder  => '_b_emitter'
);

sub _b_emitter { Fenchurch::Event::Emitter->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
