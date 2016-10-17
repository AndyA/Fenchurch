package Fenchurch::Core::Role::Group;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;

=head1 NAME

Fenchurch::Core::Role::Group - Group hashes by key(s)

=cut

sub group_by {
  my ( $self, $rows, @keys ) = @_;
  return $rows unless @keys;
  my $leaf = pop @keys;
  my $hash = {};
  for my $row (@$rows) {
    next unless defined $row;
    my $rr   = {%$row};    # clone
    my $slot = $hash;
    $slot = ( $slot->{ delete $rr->{$_} } ||= {} ) for @keys;
    push @{ $slot->{ delete $rr->{$leaf} } }, $rr;
  }
  return $hash;

}

sub stash_by {
  my ( $self, $rows, @keys ) = @_;
  return $rows unless @keys;
  my $leaf = pop @keys;
  my $hash = {};
  for my $row (@$rows) {
    next unless defined $row;
    my $slot = $hash;
    $slot = ( $slot->{ $row->{$_} } ||= {} ) for @keys;
    push @{ $slot->{ $row->{$leaf} } }, $row;
  }
  return $hash;

}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
