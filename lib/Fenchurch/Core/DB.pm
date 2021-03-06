package Fenchurch::Core::DB;

our $VERSION = "1.00";

use Fenchurch::Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

use Carp qw( confess );
use Fenchurch::Util::Data qw( flatten );
use Try::Tiny;
use Time::HiRes qw( sleep );

=head1 NAME

Fenchurch::Core::DB - Database handling

=cut

has dbh => (
  is        => 'ro',
  isa       => duck_type( ['do'] ),
  traits    => ['DoNotSerialize'],
  predicate => 'has_dbh'
);

has get_connection => (
  is        => 'ro',
  isa       => 'CodeRef',
  predicate => 'has_get_connection'
);

has in_transaction => ( is => 'rw', isa => 'Bool', default => 0 );

has _tables => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef',
  lazy    => 1,
  builder => '_b_tables',
  handles => { tables => 'elements' }
);

has _meta_cache => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
  default  => sub { {} }
);

with qw(
 Fenchurch::Core::Role::DBIWrapper
 Fenchurch::Core::Role::DBHelper
 Fenchurch::Core::Role::Group
);

sub BUILD {
  my $self = shift;
  confess "Either dbh or get_connection must be set"
   unless $self->has_dbh || $self->has_get_connection;
}

around dbh => sub {
  my $orig = shift;
  my $self = shift;

  if ( my $gc = $self->get_connection ) {
    my $dbh = $gc->();
    confess "Failed to get database handle via get_connection"
     unless defined $dbh;
    return $dbh;
  }

  return $self->$orig(@_);
};

sub no_transaction {
  my ( $self, $cb ) = @_;

  if ( $self->in_transaction ) {
    $cb->();
    return;
  }

  $self->in_transaction(1);

  try {
    $cb->();
  }
  catch {
    my $e = $_;
    confess $e;
  }
  finally {
    $self->in_transaction(0);
  };
}

sub transaction {
  my ( $self, $cb ) = @_;

  if ( $self->in_transaction ) {
    $cb->();
    return;
  }

  # Is this naughty?
  $self->dbh->{mysql_errno} = 0;

  my ( $tries, $sleep ) = ( 3, 0.1 );
  while ( $tries > 0 ) {
    $self->in_transaction(1);
    $self->do('START TRANSACTION');

    try {
      $cb->();
      $self->do('COMMIT');
      $tries = 0;
    }
    catch {
      my $e = $_;

      if ( $self->dbh->{mysql_errno} == 1213 ) {
        # Retry on deadlock
        $tries--;
        sleep $sleep;
        $sleep *= 5;
      }
      else {
        $self->do('ROLLBACK');
        $tries = 0;
        confess $e;
      }

    }
    finally {
      $self->in_transaction(0);
    };
  }
}

sub server_variables {
  my $self = shift;

  my $rc = $self->selectall_arrayref( "SHOW VARIABLES", { Slice => {} } );
  my $vars = {};
  for my $var (@$rc) {
    $vars->{ $var->{Variable_name} } = $var->{Value};
  }
  return $vars;
}

sub _b_tables { shift->selectcol_arrayref("SHOW TABLES") }

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

sub has_column {
  my ( $self, $table, @column ) = @_;
  my $meta = $self->meta_for($table);
  my @got = grep { exists $meta->{columns}{$_} } @column;
  return @got == @column;
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
