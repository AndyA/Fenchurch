package Fenchurch::Core::Role::DBIWrapper;

our $VERSION = "1.00";

use Fenchurch::Module;
use Moose::Role;

use Class::MOP::Method;
use Fenchurch::Core::Types;
use Scalar::Util qw( blessed );

requires 'dbh';

has aliases => (
  is      => 'ro',
  isa     => 'HashRefMayBeArrayRef',
  default => sub { {} },
  coerce  => 1,
);

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

sub alias {
  my ( $self, $alias ) = @_;
  return $alias unless $alias =~ /^:(.+)/;
  my $actual = $self->aliases->{$1};
  confess "No mapping for alias $1"
   unless defined $actual;
  return $actual;
}

sub quote_name {
  my ( $self, @name ) = @_;
  return join ".", map { "`$_`" } map { $self->alias($_) } @name;
}

sub quote_sql {
  my $self = shift;
  ( my $sql = join " ", map { ref $_ && 'ARRAY' eq ref $_ ? @$_ : $_ } @_ )
   =~ s/\{(:?\w+(?:\.:?\w+)*)\}/$self->quote_name(split qr{[.]}, $1)/eg;
  return $sql;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
