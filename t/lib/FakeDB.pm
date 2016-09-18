package FakeDB;

use v5.10;

use Moose;

=head1 NAME

FakeDB - A minimal fake DB handle

=cut

has log => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub { [] }
);

sub history { splice @{ shift->log } }

sub do {
  my $self = shift;
  push @{ $self->log }, [@_];
  return;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
