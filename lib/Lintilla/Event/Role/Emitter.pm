package Lintilla::Event::Role::Emitter;

use Moose::Role;
use Moose::Util::TypeConstraints;

use Lintilla::Event::Emitter;

=head1 NAME

Lintilla::Event::Role::Emitter - Be an event emitter

=cut

has emitter => (
  is       => 'ro',
  required => 1,
  isa      => duck_type( [Lintilla::Event::Emitter->interface] ),
  handles  => [Lintilla::Event::Emitter->interface],
  builder  => '_b_emitter'
);

sub _b_emitter { Lintilla::Event::Emitter->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
