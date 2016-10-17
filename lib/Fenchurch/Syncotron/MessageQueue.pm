package Fenchurch::Syncotron::MessageQueue;

our $VERSION = "1.00";

use v5.10;

use Moose;

use Carp qw( confess );
use Try::Tiny;

has _queue => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub { [] },
  traits  => ['Array'],
  handles => {
    _push     => 'push',
    _splice   => 'splice',
    available => 'count',
  }
);

has size => (
  is      => 'rw',
  isa     => 'Int',
  default => 0
);

with qw(
 Fenchurch::Core::Role::JSON
);

=head1 NAME

Fenchurch::Syncotron::MessageQueue - A persistent message queue

=cut

=head2 C<< send >>

Send messages.

=cut

sub _size {
  my ( $self, @msgs ) = @_;
  my $size = 0;
  $size += length $_ for @msgs;
  return $size;
}

sub _bump_size {
  my ( $self, $delta ) = @_;
  $self->size( $self->size + $delta );
}

sub _put {
  my ( $self, @msgs ) = @_;
  $self->_bump_size( $self->_size(@msgs) );
  $self->_push(@msgs);
}

sub _decode {
  my ( $self, @msg ) = @_;
  return map { $self->_json_decode($_) } @msg;
}

sub _take {
  my ( $self, $offset, $length ) = @_;
  my @msgs = $self->_splice( $offset, $length );
  $self->_bump_size( -$self->_size(@msgs) );
  return @msgs;
}

sub send {
  my ( $self, @msgs ) = @_;
  $self->_put( map { $self->_json_encode($_) } @msgs );
  return $self;
}

sub unsend {
  my $self = shift;
  my $count = shift // $self->available;
  $self->_take( -$count );
  return $self;
}

=head2 C<< available >>

Find out how many messages are available on the queue.

=cut

=head2 C<< peek >>

Get a copy of messages from the queue without removing them.

=cut

sub peek {
  my $self = shift;
  my $count = shift // $self->available;
  return $self->_decode( @{ $self->_queue }[0 .. $count - 1] );
}

=head2 C<< take >>

Remove messages from the queue.

=cut

sub take {
  my $self = shift;
  my $count = shift // $self->available;
  return $self->_decode( $self->_take( 0, $count ) );
}

=head2 C<< with >>

Run a callback for messages on the queue and then remove them. If the
callback errors the messages will be left on the queue.

=cut

sub with_messages {
  my $self = shift;
  my $cb   = pop;

  my @msg = $self->peek(@_);

  try { $cb->(@msg); $self->_take( 0, scalar @msg ) }
  catch { confess $_ };

  return $self;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
