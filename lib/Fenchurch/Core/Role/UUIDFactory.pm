package Fenchurch::Core::Role::UUIDFactory;

our $VERSION = "1.00";

use Fenchurch::Module;
use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Core::UUIDFactory;

has uuid_factory => (
  is      => 'ro',
  isa     => duck_type( ["make_uuid"] ),
  handles => ["make_uuid"],
  lazy    => 1,
  builder => "_b_uuid_factory"
);

=head1 NAME

Fenchurch::Core::Role::UUIDFactory - Create new UUIDs

=cut

sub _b_uuid_factory { Fenchurch::Core::UUIDFactory->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
