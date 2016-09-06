package Lintilla::Core::Pipe;

use Moose;

=head1 NAME

Lintilla::Core::Pipe - A simple FIFO object pipe

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

sub take {
  my $self = shift;
  return $self->_splice( 0, shift // $self->count );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
