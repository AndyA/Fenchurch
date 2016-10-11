package TestUA;

our $VERSION = "0.01";

use v5.10;

use Moose;

use HTTP::Request;
use HTTP::Response;

has handler => (
  is       => 'ro',
  isa      => 'CodeRef',
  required => 1
);

=head1 NAME

TestUA - A test UserAgent

=cut

sub request {
  my ( $self, $req ) = @_;
  my $body = $self->handler->( $req->content );
  #  say "# req:  ", $req->content;
  #  say "# resp: $body";
  #  say "#";
  return HTTP::Response->new( 200, "OK",
    ['Content-Type' => 'application/json'], $body );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
