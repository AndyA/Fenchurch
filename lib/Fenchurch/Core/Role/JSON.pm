package Fenchurch::Core::Role::JSON;

our $VERSION = "1.00";

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

has _json_raw => (
  is      => 'ro',
  isa     => 'JSON::XS',
  lazy    => 1,
  builder => '_b_json_raw'
);

sub _b_json     { JSON::XS->new->utf8->allow_nonref->canonical }
sub _b_json_raw { JSON::XS->new->allow_nonref->canonical }

sub json_encode {
  my ( $self, $data ) = @_;
  return $self->_json->encode($data);
}

sub json_decode {
  my ( $self, $json ) = @_;
  return undef unless defined $json;
  # If the string comes from the database it will already have been
  # decoded and its utf8 flag will be set.
  return $self->_json_raw->decode($json) if utf8::is_utf8($json);
  # Otherwise we have a utf-8 byte string
  return $self->_json->decode($json);
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
