package Fenchurch::Adhocument::Schema;

our $VERSION = "1.00";

use Moose;
use Moose::Util::TypeConstraints;

use Carp qw( confess );
use Storable qw( dclone );

use Fenchurch::Core::Util::ValidHash;

=head1 NAME

Fenchurch::Adhocument::Schema - A description of database structure

=head1 SYNOPSIS

  use Fenchurch::Adhocument::Schema;

  my $svm = Fenchurch::Adhocument::Schema->new(
    schema => {
      document => {
        table  => 'our_documents',
        pkey   => 'uuid',
        plural => 'documents',
      },
      note => {
        table    => 'our_document_notes',
        child_of => { document => 'parent_uuid' },
        order    => '+sequence',
      },
    }
  );

=head1 INTERFACE

=over

=item C<< new >>

Create a new schema.

=back

=cut

has schema => ( is => 'ro', isa => 'HashRef', required => 1 );

# Optional db handle. Adding this makes the schema concrete rather than
# abstract. We'll use this to look up the primary keys for tables.

has db => (
  is  => 'ro',
  isa => duck_type(
    ['meta_for', 'columns_for', 'settable_columns_for', 'pkey_for']
  ),
  predicate => 'has_db'
);

has _spec => (
  is      => 'ro',
  isa     => 'HashRef',
  builder => '_b_spec',
  lazy    => 1
);

has _deps => (
  is      => 'ro',
  isa     => 'HashRef',
  builder => '_b_deps',
  lazy    => 1
);

has _valid_spec => (
  is      => 'ro',
  isa     => 'Fenchurch::Core::Util::ValidHash',
  builder => '_b_valid_spec',
  lazy    => 1
);

sub _b_valid_spec {
  return Fenchurch::Core::Util::ValidHash->new(
    required => ['table'],
    optional => ['pkey', 'child_of', 'order', 'plural', 'append', 'json']
  );
}

sub _lookup_from_db {
  my ( $self, $spec ) = @_;
  return unless $self->has_db;
  return if exists $spec->{pkey};

  my @pkey = $self->db->pkey_for( $spec->{table} );
  confess "Can't handle compound primary keys for $spec->{table}"
   if @pkey > 1;

  $spec->{pkey} = $pkey[0] if @pkey;
}

sub _b_spec {
  my $self = shift;

  my $specs = dclone $self->schema;
  my $vs    = $self->_valid_spec;
  for my $spec ( values %$specs ) {
    $self->_lookup_from_db($spec);
    $vs->validate($spec);
    confess "Must have either 'table' or 'child_of'"
     unless exists $spec->{table} || exists $spec->{child_of};
  }

  while ( my ( $kind, $spec ) = each %$specs ) {
    while ( my ( $pkind, $fkey ) = each %{ $spec->{child_of} // {} } ) {
      my $parent     = $specs->{$pkind} // confess "Unknown kind $pkind";
      my $child_name = $spec->{plural}  // $kind;
      $parent->{children}{$child_name} = { kind => $kind, fkey => $fkey };
    }
  }

  return $specs;
}

sub _b_deps {
  my $self = shift;
  my $deps = {};
  while ( my ( $kind, $spec ) = each %{ $self->schema } ) {
    while ( my ( $pkind, $fkey ) = each %{ $spec->{child_of} // {} } ) {
      push @{ $deps->{$pkind} }, $kind;
    }
  }
  return $deps;
}

sub spec_for {
  my ( $self, $kind ) = @_;
  return $self->_spec->{$kind} // confess "Unknown kind $kind";
}

sub spec_for_root {
  my ( $self, $kind ) = @_;
  my $spec = $self->spec_for($kind);
  confess "$kind has no pkey" unless exists $spec->{pkey};
  return $spec;
}

sub pkey_for {
  my $self = shift;
  return $self->spec_for_root(@_)->{pkey};
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
