package Fenchurch::Core::Role::JSON;

use Moose::Role;

use JSON ();

=head1 NAME

Fenchurch::Core::Role::JSON - Create a JSON (de)serialiser

=cut

has _json => (
  is      => 'ro',
  isa     => 'JSON',
  lazy    => 1,
  builder => '_b_json'
);

sub _b_json { JSON->new->utf8->allow_nonref->canonical }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
