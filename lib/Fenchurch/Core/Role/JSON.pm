package Fenchurch::Core::Role::JSON;

our $VERSION = "1.00";

use Moose::Role;

use JSON ();

# Transitional shim - depend on DBD::mysql version
use DBD::mysql;

=head1 NAME

Fenchurch::Core::Role::JSON - Create a JSON (de)serialiser

=cut

has _json_utf8 => (
  is      => 'ro',
  isa     => 'JSON',
  lazy    => 1,
  builder => '_b_json_utf8'
);

has _json_raw => (
  is      => 'ro',
  isa     => 'JSON',
  lazy    => 1,
  builder => '_b_json_raw'
);

sub _b_json_utf8 { JSON->new->utf8->allow_nonref->canonical }
sub _b_json_raw  { JSON->new->allow_nonref->canonical }

sub _old_dbd_mysql {
  return $DBD::mysql::VERSION < 4.042;
}

sub json_encode {
  my ( $self, $data ) = @_;
  if ( $self->_old_dbd_mysql ) { return $self->_json_utf8->encode($data) }
  else                         { return $self->_json_raw->encode($data) }
}

sub json_decode {
  my ( $self, $json ) = @_;
  return undef unless defined $json;
  if ( $self->_old_dbd_mysql ) {
    # If the string comes from the database it will already have been
    # decoded and its utf8 flag will be set.
    return $self->_json_raw->decode($json) if utf8::is_utf8($json);
    # Otherwise we have a utf-8 byte string
    return $self->_json_utf8->decode($json);
  }
  else {
    return $self->_json_raw->decode($json);
  }
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
