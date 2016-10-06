package Fenchurch::Core::Role::JSON;

our $VERSION = "0.01";

use Moose::Role;

use JSON::XS ();

=head1 NAME

Fenchurch::Core::Role::JSON - Create a JSON (de)serialiser

=cut

has _json => (
  is      => 'ro',
  isa     => 'JSON::XS',
  lazy    => 1,
  builder => '_b_json'
);

sub _b_json { JSON::XS->new->utf8->allow_nonref->canonical }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
