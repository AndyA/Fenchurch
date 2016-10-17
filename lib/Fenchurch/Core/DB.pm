package Fenchurch::Core::DB;

our $VERSION = "1.00";

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

use Carp qw( confess );
use Try::Tiny;

=head1 NAME

Fenchurch::Core::DB - Database handling

=cut

has dbh => (
  is       => 'ro',
  isa      => duck_type( ['do'] ),
  traits   => ['DoNotSerialize'],
  required => 1
);

has in_transaction => ( is => 'rw', isa => 'Bool', default => 0 );

# The table name map: maps our internal table names to the
# actual db tables.

has _meta_cache => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
  default  => sub { {} }
);

with qw(
 Fenchurch::Core::Role::DBIWrapper
 Fenchurch::Core::Role::Group
);

sub transaction {
  my ( $self, $cb ) = @_;

  if ( $self->in_transaction ) {
    $cb->();
    return;
  }

  $self->in_transaction(1);
  $self->do('START TRANSACTION');

  try {
    $cb->();
    $self->do('COMMIT');
  }
  catch {
    my $e = $_;
    $self->do('ROLLBACK');
    confess $e;
  }
  finally {
    $self->in_transaction(0);
  };
}

sub _meta_for {
  my ( $self, $table ) = @_;
  my $rc
   = $self->selectall_arrayref( "DESCRIBE {$table}", { Slice => {} } );

  my %columns = ();
  my @pkey    = ();

  for my $col (@$rc) {
    my $name = $col->{Field};
    my $pri = $col->{Key} eq 'PRI' ? 1 : 0;
    push @pkey, $name if $pri;
    $columns{$name} = {
      primary  => $pri,
      type     => $col->{Type},
      default  => $col->{Default},
      nullable => $col->{Null} eq 'YES' ? 1 : 0,
      auto     => $col->{Extra} eq 'auto_increment' ? 1 : 0
    };
  }

  return { columns => \%columns, pkey => \@pkey };
}

sub meta_for {
  my ( $self, $table ) = @_;
  my $mc = $self->_meta_cache;
  return ( $mc->{$table} //= $self->_meta_for($table) );
}

sub columns_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  return sort keys %{ $meta->{columns} };
}

sub numeric_columns_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  my $cols = $meta->{columns};
  return sort grep {
    $cols->{$_}{type} =~ /^ (?: decimal | double | float | int |
                            (?: big | medium | small | tiny ) int)/x
  } keys %$cols;
}

sub settable_columns_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  my $cols = $meta->{columns};
  return sort grep { !$cols->{$_}{auto} } keys %$cols;
}

sub pkey_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  return sort @{ $meta->{pkey} };
}

sub parse_order {
  my ( $self, $order ) = @_;
  my @term = ();
  for my $fld ( split /\s*,\s*/, $order ) {
    my ( $dir, $fname )
     = $fld =~ m{^([-+])(.+)} ? ( $1, $2 ) : ( '+', $fld );
    push @term, join ' ', "{$fname}", $dir eq '+' ? 'ASC' : 'DESC';
  }
  return join( ', ', @term );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
