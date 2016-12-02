package Fenchurch::Syncotron::HTTP::Client;

our $VERSION = "1.00";

use v5.10;

use Moose;

has uri => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::JSON
 Fenchurch::Syncotron::HTTP::Role::Endpoint
 Fenchurch::Syncotron::HTTP::Role::UserAgent
);

=head1 NAME

Fenchurch::Syncotron::HTTP::Client - Client to sync over http

=cut

sub _find_remote_node_name {
  my $self = shift;
  return if $self->has_remote_node_name;

  # Send an empty message
  my $reply = $self->_post( $self->_make_message );
  die "No 'node' in reply" unless defined $reply->{node};
  $self->remote_node_name( $reply->{node} );
}

sub next {
  my $self = shift;

  $self->_find_remote_node_name;

  my $client = $self->client;
  my $server = $self->server;

  $client->next;
  $server->next;

  my $msg = $self->_make_message(
    client => [$server->mq_out->take],
    server => [$client->mq_out->take]
  );

  my $reply = $self->_post($msg);

  $self->_handle_remote_node_name($reply);

  $client->mq_in->send( @{ $reply->{server} } );
  $server->mq_in->send( @{ $reply->{client} } );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
