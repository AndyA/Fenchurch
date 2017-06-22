package Fenchurch::Syncotron::HTTP::Server;

our $VERSION = "1.00";

use v5.10;

use Moose;

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::JSON
 Fenchurch::Syncotron::HTTP::Role::Endpoint
);

=head1 NAME

Fenchurch::Syncotron::HTTP::Server - Handle HTTP sync requests

=cut

sub handle {
  my $self = shift;
  return $self->json_encode_utf8( $self->handle_raw(@_) );
}

sub handle_raw {
  my ( $self, $body ) = @_;

  $self->log->debug("Handling sync request");

  my $msg = $self->json_decode_utf8($body);

  $self->_handle_remote_node_name($msg);

  my $client = $self->client;
  my $server = $self->server;

  $client->forget_state;    # Force reload

  $client->mq_in->send( @{ $msg->{client} } );
  $server->mq_in->send( @{ $msg->{server} } );

  $client->next;
  $server->next;

  $client->save_state;

  my $reply = $self->_make_message(
    client => [$client->mq_out->take],
    server => [$server->mq_out->take]
  );

  return $reply;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
