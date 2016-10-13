package Fenchurch::Syncotron::HTTP::Role::Endpoint;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;
use Moose::Util::TypeConstraints;

use Carp qw( confess );
use Fenchurch::Syncotron::Client;
use Fenchurch::Syncotron::MessageQueue;
use Fenchurch::Syncotron::Server;

=head1 NAME

Fenchurch::Syncotron::HTTP::Role::Endpoint - An http endpoint

=cut

has remote_node_name => (
  is        => 'rw',
  isa       => 'Str',
  predicate => 'has_remote_node_name'
);

has 'client' => (
  is      => 'ro',
  isa     => duck_type( ['next'] ),
  lazy    => 1,
  builder => '_b_client'
);

has 'server' => (
  is      => 'ro',
  isa     => duck_type( ['next'] ),
  lazy    => 1,
  builder => '_b_server'
);

with qw(
 Fenchurch::Core::Role::NodeName
 Fenchurch::Event::Role::Emitter
 Fenchurch::Syncotron::Role::Versions
);

sub _b_client {
  my $self = shift;

  confess "remote_node_name not set"
   unless $self->has_remote_node_name;

  my $client = Fenchurch::Syncotron::Client->new(
    db               => $self->db,
    node_name        => $self->node_name,
    remote_node_name => $self->remote_node_name,
    versions         => $self->versions
  );

  $self->emit( made_client => $client );

  return $client;
}

sub _b_server {
  my $self = shift;

  my $server = Fenchurch::Syncotron::Server->new(
    db        => $self->db,
    node_name => $self->node_name,
    versions  => $self->versions
  );

  $self->emit( made_server => $server );

  return $server;
}

sub _handle_remote_node_name {
  my ( $self, $msg ) = @_;

  die "No 'node' in message" unless defined $msg->{node};

  if ( $self->has_remote_node_name ) {
    die "Remote node name mismatch; expected ", $self->remote_node_name,
     " got ", $msg->{node}
     unless $msg->{node} eq $self->remote_node_name;
  }
  else {
    $self->remote_node_name( $msg->{node} );
  }
}

sub _make_message {
  my $self = shift;
  return { node => $self->node_name, @_ };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
