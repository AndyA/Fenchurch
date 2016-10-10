package Fenchurch::Core::Pipe;

our $VERSION = "1.00";

use Moose;

=head1 NAME

Fenchurch::Core::Pipe - A simple FIFO object pipe

=cut

has _pipe => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub { [] },
  traits  => ['Array'],
  handles => {
    put      => 'push',
    get      => 'shift',
    count    => 'count',
    is_empty => 'is_empty',
    _splice  => 'splice'
  }
);

=head2 C<< take >>

Take n (default all) items from pipe.

=cut

sub take {
  my $self = shift;
  return $self->_splice( 0, shift // $self->count );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
