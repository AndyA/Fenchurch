package Fenchurch::Core::Role::JSON;

our $VERSION = "1.00";

use Moose::Role;

use JSON ();

=head1 NAME

Fenchurch::Core::Role::JSON - Create a JSON (de)serialiser

=cut

has _json_utf8 => (
  is      => 'ro',
  isa     => 'JSON',
  lazy    => 1,
  builder => '_b_json_utf8'
);

has _json => (
  is      => 'ro',
  isa     => 'JSON',
  lazy    => 1,
  builder => '_b_json'
);

sub _b_json_utf8 { JSON->new->utf8->allow_nonref->canonical }
sub _b_json      { JSON->new->allow_nonref->canonical }

sub json_encode {
  my ( $self, $data ) = @_;
  return $self->_json->encode($data);
}

sub json_decode {
  my ( $self, $json ) = @_;
  return undef unless defined $json;
  return $self->_json->decode($json);
}

sub json_encode_utf8 {
  my ( $self, $data ) = @_;
  return $self->_json_utf8->encode($data);
}

sub json_decode_utf8 {
  my ( $self, $json ) = @_;
  return undef unless defined $json;
  return $self->_json_utf8->decode($json);
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
