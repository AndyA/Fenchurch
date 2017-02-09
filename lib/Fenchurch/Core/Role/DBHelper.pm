package Fenchurch::Core::Role::DBHelper;

our $VERSION = "1.00";

use v5.10;

use Moose::Role;

requires 'do';

=head1 NAME

Fenchurch::Core::Role::DBHelper - DB helper functions

=cut

sub _insert_or_replace {
  my ( $self, $cmd, $table, @rows ) = @_;

  return unless @rows;
  my @cols = sort keys %{ $rows[0] };
  my $vals = '(' . join( ', ', ("?") x @cols ) . ')';

  $self->do(
    join( ' ',
      "$cmd INTO {$table} (",
      join( ', ', map "{$_}", @cols ),
      ") VALUES",
      join( ', ', ($vals) x @rows ) ),
    {},
    map { ( @{$_}{@cols} ) } @rows
  );
}

sub insert  { shift->_insert_or_replace( "INSERT",  @_ ) }
sub replace { shift->_insert_or_replace( "REPLACE", @_ ) }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
