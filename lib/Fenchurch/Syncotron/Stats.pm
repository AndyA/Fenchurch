package Fenchurch::Syncotron::Stats;

our $VERSION = "1.00";

use v5.10;

use Moose;

has stats => (
  is       => 'ro',
  isa      => 'HashRef[HashRef]',
  required => 1,
  default  => sub { {} }
);

=head1 NAME

Fenchurch::Syncotron::Stats - Gather connection statistics

=cut

sub _count {
  my ( $self, $kind, $msg ) = @_;

  my $st = $self->stats->{$kind} //= {};

  my $size = length $msg;

  $st->{size} += $size;
  $st->{min} = $size
   unless exists $st->{min} && $st->{min} < $size;
  $st->{max} = $size
   unless exists $st->{max} && $st->{max} > $size;
  $st->{count}++;

  return $msg;
}

sub report {
  my $self = shift;

  my $out = {};
  while ( my ( $kind, $stats ) = each %{ $self->stats } ) {
    my $st = $out->{$kind} = {%$stats};    # Shallow clone
    $st->{average} = $st->{size} / $st->{count};
  }

  return $out;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
