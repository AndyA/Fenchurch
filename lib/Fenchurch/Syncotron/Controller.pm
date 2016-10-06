package Fenchurch::Syncotron::Controller;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with 'Fenchurch::Core::Role::JSON';

has despatcher => (
  is       => 'ro',
  isa      => duck_type( ['despatch'] ),
  required => 1
);

has _replies => (
  is      => 'ro',
  traits  => ['Array'],
  isa     => 'ArrayRef',
  default => sub { [] },
  handles => { reply => 'push' }
);

=head1 NAME

Fenchurch::Syncotron::Controller - Sync protocol controller

=cut

sub handle_raw_message {
  my ( $self, $msgs ) = @_;

  my $de      = $self->despatcher;
  my $replies = $self->_replies;

  for my $ev (@$msgs) {
    $de->despatch( $ev, $self );
  }

  return [splice @$replies];
}

=head2 C<< handle_message >>

Receive a message and return a response.

=cut

sub handle_message {
  my ( $self, $msgs ) = @_;
  my $js = $self->_json;
  return $js->encode( $self->handle_raw_message( $js->decode($msgs) ) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
