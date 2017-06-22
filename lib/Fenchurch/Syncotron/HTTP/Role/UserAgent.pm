package Fenchurch::Syncotron::HTTP::Role::UserAgent;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Stats;

use LWP::UserAgent;

requires 'log', 'uri';

has _ua => (
  is      => 'ro',
  isa     => duck_type( ['request'] ),
  lazy    => 1,
  builder => '_b_ua'
);

has ['user', 'pass', 'facility'] => (
  is  => 'ro',
  isa => 'Maybe[Str]'
);

has stats => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_stats'
);

=head1 NAME

Fenchurch::Syncotron::HTTP::Role::UserAgent - Add an LWP::UserAgent

=cut

sub _netloc {
  my $self = shift;
  my $u    = URI->new( $self->uri );
  return join ':', $u->host, $u->port;
}

sub _b_ua {
  my $self = shift;
  my $ua   = LWP::UserAgent->new;
  if ( defined $self->user && defined $self->pass ) {
    $ua->credentials( $self->_netloc, $self->facility,
      $self->user, $self->pass );
  }
  return $ua;
}

sub _b_stats { Fenchurch::Syncotron::Stats->new }

sub _post {
  my ( $self, $msg ) = @_;

  my $stats = $self->stats;

  my $req = HTTP::Request->new( 'POST', $self->uri );
  $req->header( 'Content-Type' => 'application/json;charset=utf-8' );
  $req->content( $stats->count( send => $self->json_encode_utf8($msg) ) );

  $self->log->debug( "POST ", $self->uri );
  my $resp = $self->_ua->request($req);
  $self->log->debug( "Response: ", $resp->status_line );

  return $self->json_decode_utf8(
    $stats->count( receive => $resp->content ) )
   if $resp->is_success;

  die join "\n", $resp->status_line, $resp->decoded_content;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
