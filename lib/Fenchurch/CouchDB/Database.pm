package Fenchurch::CouchDB::Database;

our $VERSION = "0.01";

use v5.10;

use Fenchurch::Moose;
use Fenchurch::CouchDB;

=head1 NAME

Fenchurch::CouchDB::Database - A CouchDB database

=cut

has db => (
  isa        => "Fenchurch::CouchDB",
  lazy_build => 1,
);

has name => (
  isa      => 'Str',
  required => 1,
);

sub _build_db ($self) {
  return Fenchurch::CouchDB->new;
}

sub _uri_for ( $self, @part ) {
  return join '/', '', $self->name, @part;
}

sub exists ($self) {
  my ( $resp, $data ) = $self->db->raw_request( GET => $self->_uri_for );
  return if $resp->code eq 404;
  return $data if $resp->is_success;
  die $resp->status_line, ": ", $resp->content;
}

sub delete ($self) {
  $self->db->delete( $self->_uri_for );
}

sub create ($self) {
  $self->db->put( $self->_uri_for, undef );
}

sub put ( $self, $key, $doc ) {
  $self->db->put( $self->_uri_for($key), $doc );
}

sub get ( $self, $key ) {
  $self->db->get( $self->_uri_for($key) );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
