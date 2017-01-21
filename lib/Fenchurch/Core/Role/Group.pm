package Fenchurch::Core::Role::Group;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;

use Carp qw( confess );

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

sub _deep_unique {
  my ( $self, $obj ) = @_;

  die unless ref $obj;

  if ( 'ARRAY' eq ref $obj ) {
    confess "Multiple values for key" unless 1 == @$obj;
    return $obj->[0];
  }

  if ( 'HASH' eq ref $obj ) {
    return { map { $_ => $self->_deep_unique( $obj->{$_} ) } keys %$obj };
  }

  die;
}

sub group_unique_by {
  my ( $self, @args ) = @_;
  return $self->_deep_unique( $self->group_by(@args) );
}

sub stash_unique_by {
  my ( $self, @args ) = @_;
  return $self->_deep_unique( $self->stash_by(@args) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
