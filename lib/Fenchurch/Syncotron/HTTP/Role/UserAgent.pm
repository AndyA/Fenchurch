package Fenchurch::Syncotron::HTTP::Role::UserAgent;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::Stats;

use LWP::UserAgent;

has _ua => (
  is      => 'ro',
  isa     => duck_type( ['request'] ),
  lazy    => 1,
  builder => '_b_ua'
);

has stats => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_stats'
);

=head1 NAME

Fenchurch::Syncotron::HTTP::Role::UserAgent - Add an LWP::UserAgent

=cut

sub _b_ua    { LWP::UserAgent->new }
sub _b_stats { Fenchurch::Syncotron::Stats->new }

sub _post {
  my ( $self, $msg ) = @_;

  my $stats = $self->stats;

  my $req = HTTP::Request->new( 'POST', $self->uri );
  $req->header( 'Content-Type' => 'application/json;charset=utf-8' );
  $req->content( $stats->_count( send => $self->json_encode($msg) ) );

  my $resp = $self->_ua->request($req);

  return $self->json_decode( $stats->_count( receive => $resp->content ) )
   if $resp->is_success;

  die join "\n", $resp->status_line, $resp->decoded_content;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
