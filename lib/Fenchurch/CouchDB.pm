package Fenchurch::CouchDB;

our $VERSION = "0.01";

use v5.10;

use Fenchurch::Moose;
use Fenchurch::Core::Types;

=head1 NAME

Fenchurch::CouchDB - CouchDB driver

=cut

use LWP::UserAgent;
use URI;

has ua => (
  isa        => "LWP::UserAgent",
  lazy_build => 1,
);

has base => (
  isa      => "Fenchurch::URI",
  required => 1,
  coerce   => 1,
  default  => "http://localhost:5984/",
);

with qw(
 Fenchurch::Core::Role::JSON
);

sub _build_ua ($self) {
  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;
  return $ua;
}

sub make_request ( $self, $method, $uri, $content = undef ) {
  my $ep = URI->new_abs( $uri, $self->base );
  my $req = HTTP::Request->new( $method, $ep );

  if ( defined $content ) {
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( $self->json_encode_utf8($content) );
  }
  return $req;
}

sub raw_request ( $self, $method, $uri, $content = undef ) {
  my $req = $self->make_request( $method, $uri, $content );
  say "request: $method ", $req->uri;
  my $resp = $self->ua->request($req);
  say "response: ", $resp->status_line, ": ", $resp->content;
  return ( $resp, $self->json_decode_utf8( $resp->content ) )
   if wantarray && $resp->is_success;
  return $resp;
}

sub request ( $self, $method, $uri, $content = undef ) {
  my ( $resp, $data ) = $self->raw_request( $method, $uri, $content );
  return $data if $resp->is_success;
  die $resp->status_line, ": ", $resp->content;
}

sub delete ( $self, $uri ) {
  $self->request( DELETE => $uri );
}

sub get ( $self, $uri ) {
  $self->request( GET => $uri );
}

sub put ( $self, $uri, $json ) {
  $self->request( PUT => $uri, $json );
}

sub post ( $self, $uri, $json ) {
  $self->request( POST => $uri, $json );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
