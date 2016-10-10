package Fenchurch::Syncotron::MessageQueue;

our $VERSION = "1.00";

use v5.10;

use Moose;

use Carp qw( confess );
use Try::Tiny;

has ['role', 'from', 'to'] => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has _queue => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub { [] },
  traits  => ['Array'],
  handles => {
    _put      => 'push',
    available => 'count',
  }
);

with 'Fenchurch::Core::Role::JSON';

=head1 NAME

Fenchurch::Syncotron::MessageQueue - A persistent message queue

=cut

=head2 C<< send >>

Send messages.

=cut

sub send {
  my ( $self, @msgs ) = @_;

  return $self unless @msgs;

  my $q    = $self->_queue;
  my $json = $self->_json;

  $self->_put( map { $json->encode($_) } @msgs );

  return $self;
}

=head2 C<< available >>

Find out how many messages are available on the queue.

=cut

=head2 C<< peek >>

Get a copy of messages from the queue without removing them.

=cut

sub _decode {
  my ( $self, @msg ) = @_;
  my $json = $self->_json;
  return map { $json->decode($_) } @msg;
}

sub peek {
  my $self = shift;

  my $q = $self->_queue;
  my $count = shift // scalar @$q;

  return $self->_decode( @{$q}[0 .. $count - 1] );
}

=head2 C<< take >>

Remove messages from the queue.

=cut

sub take {
  my $self = shift;

  my $q = $self->_queue;
  my $count = shift // scalar @$q;

  return $self->_decode( splice @$q, 0, $count );
}

=head2 C<< with >>

Run a callback for messages on the queue and then remove them. If the
callback errors the messages will be left on the queue.

=cut

sub with_messages {
  my $self = shift;
  my $cb   = pop;

  my $q   = $self->_queue;
  my @msg = $self->peek(@_);

  try { $cb->(@msg); splice @$q, 0, scalar @msg }
  catch { confess $_ };

  return $self;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
