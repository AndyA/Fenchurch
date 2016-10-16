package Fenchurch::Adhocument;

our $VERSION = "1.00";

use Moose;

use Carp qw( croak );
use Fenchurch::Adhocument::Schema;

=head1 NAME

Fenchurch::Adhocument - Document semantics mini-ORM

=cut

has numify => (
  is       => 'ro',
  isa      => 'Bool',
  required => 1,
  default  => 0
);

with 'Fenchurch::Core::Role::DB',
 'Fenchurch::Core::Role::JSON',
 'Fenchurch::Adhocument::Role::Schema',
 'Fenchurch::Event::Role::Emitter';

sub _exists {
  my ( $self, $spec, @ids ) = @_;

  my $pk  = $self->db->quote_name( $spec->{pkey} );
  my @sql = (
    "SELECT $pk FROM",
    $self->db->quote_name( $spec->{table} ),
    "WHERE $pk IN (",
    join( ', ', map '?', @ids ),
    ')',
    'ORDER BY FIELD(',
    join( ', ', $pk, map '?', @ids ),
    ')'
  );

  return $self->db->selectcol_arrayref( join( ' ', @sql ), {},
    @ids, @ids );
}

sub _load_raw {
  my ( $self, $spec, $key, @ids ) = @_;

  my @bind = @ids;
  my @sql  = (
    'SELECT * FROM',
    $self->db->quote_name( $spec->{table} ),
    'WHERE', $self->db->quote_name($key),
    'IN (', join( ', ', map '?', @ids ), ")"
  );

  my @ord = ();

  push @ord, join ' ', 'FIELD(',
   join( ', ', $self->db->quote_name($key), map '?', @ids ), ')';
  push @bind, @ids;

  push @ord, join ' ', $self->db->parse_order( $spec->{order} )
   if exists $spec->{order};

  push @ord, $self->db->quote_name( $spec->{pkey} )
   if exists $spec->{pkey};

  push @sql, 'ORDER BY', join( ', ', @ord ) if @ord;

  return $self->db->selectall_arrayref( join( ' ', @sql ),
    { Slice => {} }, @bind );
}

sub _load {
  my ( $self, $spec, $key, @ids ) = @_;
  my $rc = $self->_load_raw( $spec, $key, @ids );
  return unless $rc;

  if ( $self->numify ) {
    my @nc = $self->db->numeric_columns_for( $spec->{table} );
    for my $row (@$rc) {
      for my $nf (@nc) {
        $row->{$nf} += 0 if defined $row->{$nf};
      }
    }
  }

  my $json = $spec->{json} // [];
  if (@$json) {
    for my $row (@$rc) {
      for my $nf (@$json) {
        $row->{$nf} = $self->_json_decode( $row->{$nf} );
      }
    }
  }

  return $rc;
}

sub _load_deep {
  my ( $self, $spec, $key, @ids ) = @_;

  return [] unless @ids;

  my $docs = $self->_load( $spec, $key, @ids );

  if ( exists $spec->{children} ) {
    my $pkey = $spec->{pkey}
     // croak "Can't load children of kind with no primary key";
    my @pids = map { $_->{$pkey} } @$docs;
    for my $name ( keys %{ $spec->{children} } ) {
      my $info  = $spec->{children}{$name};
      my $fkey  = $info->{fkey};
      my $cspec = $self->spec_for( $info->{kind} );
      my $kdocs = $self->_load_deep( $cspec, $fkey, @pids );
      my $kids  = $self->db->group_by( $kdocs, $fkey );
      for my $doc (@$docs) {
        $doc->{$name} = delete $kids->{ $doc->{$pkey} } // [];
      }
    }
  }

  return $docs;
}

sub _get_pkeys {
  my ( $self, $spec, $key, @ids ) = @_;

  my $pkey = $spec->{pkey} // croak "kind has no pkey";

  return @ids if $pkey eq $key;    # Already have pkey

  return @{
    $self->db->selectcol_arrayref(
      join( ' ',
        'SELECT', $self->db->quote_name($pkey),
        'FROM',   $self->db->quote_name( $spec->{table} ),
        'WHERE',  $self->db->quote_name($key),
        'IN (', join( ', ', map '?', @ids ),
        ')' ),
      {},
      @ids
    ) };
}

sub _delete {
  my ( $self, $spec, $key, @ids ) = @_;

  my $sql = join ' ',
   'DELETE FROM', $self->db->quote_name( $spec->{table} ),
   'WHERE',       $self->db->quote_name($key),
   'IN (',        join( ', ', map '?', @ids ), ")";

  $self->db->do( $sql, {}, @ids );
}

sub _delete_deep {
  my ( $self, $spec, $key, @ids ) = @_;

  return unless @ids;

  $self->transaction(
    sub {
      if ( exists $spec->{children} ) {
        my @pids = $self->_get_pkeys( $spec, $key, @ids );
        for my $name ( keys %{ $spec->{children} } ) {
          my $info  = $spec->{children}{$name};
          my $cspec = $self->spec_for( $info->{kind} );
          $self->_delete_deep( $cspec, $info->{fkey}, @pids );
        }
      }

      $self->_delete( $spec, $key, @ids );
    }
  );
}

sub _check_columns {
  my ( $self, $spec, $extra, @docs ) = @_;

  my %ok_cols = map { $_ => 1 } @$extra,
   $self->db->settable_columns_for( $spec->{table} );
  my %bad_cols     = ();
  my %missing_cols = ();

  for my $doc (@docs) {
    $bad_cols{$_}++     for grep { !$ok_cols{$_} } keys %$doc;
    $missing_cols{$_}++ for grep { !exists $doc->{$_} } keys %ok_cols;
  }

  my @bad = sort keys %bad_cols;
  croak "Data has columns not found in ", $spec->{table}, ": ",
   join( ', ', map "'$_'", @bad )
   if @bad;

  my @missing = sort keys %missing_cols;
  croak "Data lacks columns found in ", $spec->{table}, ": ",
   join( ', ', map "'$_'", @missing )
   if @missing;
}

sub _insert {
  my ( $self, $spec, @docs ) = @_;

  my @cols = $self->db->settable_columns_for( $spec->{table} );

  my $vals = join '', '(', join( ', ', map '?', @cols ), ')';
  my $sql = join ' ',
   'INSERT INTO', $self->db->quote_name( $spec->{table} ),
   '(', join( ', ', map { $self->db->quote_name($_) } @cols ),
   ') VALUES', join( ', ', ($vals) x @docs );

  my %is_json = map { $_ => 1 } @{ $spec->{json} // [] };
  my @bind = ();
  for my $doc (@docs) {
    for my $col (@cols) {
      my $val = $doc->{$col};
      push @bind, $is_json{$col} ? $self->_json_encode($val) : $val;
    }
  }

  $self->db->do( $sql, {}, @bind );
}

sub _insert_deep {
  my ( $self, $spec, @docs ) = @_;

  return unless @docs;

  my @kids = keys %{ $spec->{children} // {} };

  $self->transaction(
    sub {
      if (@kids) {
        my $pkey = $spec->{pkey}
         // croak "Can't save a kind with no primary key";

        for my $name (@kids) {
          my $info  = $spec->{children}{$name};
          my $cspec = $self->spec_for( $info->{kind} );
          my @kids  = ();
          for my $doc (@docs) {
            for my $kid ( @{ $doc->{$name} || [] } ) {
              push @kids, { %$kid, $info->{fkey} => $doc->{$pkey} };
            }
          }
          $self->_insert_deep( $cspec, @kids );
        }
      }

      $self->_check_columns( $spec, \@kids, @docs );
      $self->_insert( $spec, @docs );
    }
  );
}

sub load {
  my ( $self, $kind, @ids ) = @_;
  my $spec   = $self->spec_for_root($kind);
  my $pkey   = $spec->{pkey};
  my $docs   = $self->_load_deep( $spec, $pkey, @ids );
  my $by_key = $self->db->stash_by( $docs, $pkey );
  my $res    = [map { ( $by_key->{$_} // [] )->[0] } @ids];
  $self->emit( 'load', $kind, \@ids, $res );
  return $res;
}

sub load_by_key {
  my ( $self, $kind, $key, @ids ) = @_;
  return $self->_load_deep( $self->spec_for($kind), $key, @ids );
}

sub delete {
  my ( $self, $kind, @ids ) = @_;
  my $spec = $self->spec_for_root($kind);
  die "Can't delete: schema is append only" if $spec->{append};
  $self->emit( 'delete', $kind, \@ids );
  $self->_delete_deep( $spec, $spec->{pkey}, @ids );
}

sub _only_once {
  my ( $self, @ids ) = @_;
  my %seen = ();
  $seen{$_}++ for @ids;
  my @multi = grep { $seen{$_} > 1 } keys %seen;
  croak "These ids appeared more than once: ", join( ', ', @multi )
   if @multi;
}

sub save {
  my ( $self, $kind, @docs ) = @_;

  my $spec = $self->spec_for_root($kind);
  my $pkey = $spec->{pkey};

  my @ids = map { $_->{$pkey} } @docs;

  # Check each id is used only once
  $self->_only_once(@ids);

  $self->transaction(
    sub {
      $self->delete( $kind, @ids ) unless $spec->{append};
      $self->_insert_deep( $spec, @docs );
      $self->emit( 'save', $kind, \@docs );
    }
  );
}

sub exists {
  my ( $self, $kind, @ids ) = @_;
  return $self->_exists( $self->spec_for_root($kind), @ids );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
