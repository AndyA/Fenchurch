package Fenchurch::Core::Role::DBIWrapper;

our $VERSION = "0.01";

use v5.10;

use Moose::Role;

use Class::MOP::Method;
use Scalar::Util qw( blessed );

requires 'dbh', 'quote_sql';

=head1 NAME

Fenchurch::Core::Role::DBIWrapper - Provide augmented version of DBI interface

=cut

{
  my @METHODS = qw(
   do
   prepare
   prepare_cached
   selectall_array
   selectall_arrayref
   selectall_hashref
   selectcol_arrayref
   selectrow_array
   selectrow_arrayref
   selectrow_hashref
  );

  my $meta = __PACKAGE__->meta;
  for my $method (@METHODS) {
    $meta->add_method(
      $method,
      Class::MOP::Method->wrap(
        sub {
          my ( $self, $sql, @args ) = @_;
          $self->dbh->$method( blessed $sql
            ? $sql
            : $self->quote_sql($sql), @args );
        },
        name                 => $method,
        package_name         => __PACKAGE__,
        associated_metaclass => $meta
      )
    );
  }
}

sub selectcol_array {
  my $self = shift;
  return @{ $self->selectcol_arrayref(@_) };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
