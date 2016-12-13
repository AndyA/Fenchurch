package Fenchurch::Adhocument;

our $VERSION = "1.00";

use Moose;

use Carp qw( confess );
use Fenchurch::Adhocument::Schema;
use Storable qw( dclone );

=head1 NAME

Fenchurch::Adhocument - Document semantics mini-ORM

=cut

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::DB
 Fenchurch::Core::Role::JSON
 Fenchurch::Adhocument::Role::Options
 Fenchurch::Adhocument::Role::Schema
 Fenchurch::Event::Role::Emitter
);

sub _exists {
  my ( $self, $spec, @ids ) = @_;

  my $pk    = $spec->{pkey};
  my $table = $spec->{table};

  return $self->db->selectcol_arrayref(
    [ "SELECT {$pk} FROM {$table} WHERE {$pk} IN (",
      join( ', ', map '?', @ids ),
      ') ORDER BY FIELD(',
      join( ', ', "{$pk}", map '?', @ids ), ')'
    ],
    {},
    @ids, @ids
  );
}

sub _load_raw {
  my ( $self, $spec, $key, @ids ) = @_;

  my @bind  = @ids;
  my $table = $spec->{table};

  my @sql = (
    "SELECT * FROM {$table} WHERE {$key} IN (",
    join( ', ', map '?', @ids ), ")"
  );

  my @ord = ();

  push @ord, join ' ', 'FIELD(',
   join( ', ', "{$key}", map '?', @ids ), ')';
  push @bind, @ids;

  push @ord, join ' ', $self->db->parse_order( $spec->{order} )
   if exists $spec->{order};

  push @ord, "{$spec->{pkey}}"
   if exists $spec->{pkey};

  push @sql, 'ORDER BY', join( ', ', @ord ) if @ord;

  return $self->db->selectall_arrayref( \@sql, { Slice => {} }, @bind );
}

sub _deepen {
  my ( $self, $spec, $docs ) = @_;

  if ( $self->numify ) {
    my @nc = $self->db->numeric_columns_for( $spec->{table} );
    for my $row (@$docs) {
      for my $nf (@nc) {
        $row->{$nf} += 0 if defined $row->{$nf};
      }
    }
  }

  my $json = $spec->{json} // [];
  if (@$json) {
    for my $row (@$docs) {
      for my $nf (@$json) {
        $row->{$nf} = $self->json_decode( $row->{$nf} );
      }
    }
  }

  if ( exists $spec->{children} ) {
    my $pkey = $spec->{pkey}
     // confess "Can't load children of kind with no primary key";
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

sub _load_deep {
  my ( $self, $spec, $key, @ids ) = @_;

  return [] unless @ids;

  my $docs = $self->_load_raw( $spec, $key, @ids );
  return $self->_deepen( $spec, $docs );
}

sub _get_pkeys {
  my ( $self, $spec, $key, @ids ) = @_;

  my $pkey = $spec->{pkey} // confess "kind has no pkey";
  my $table = $spec->{table};

  return @ids if $pkey eq $key;    # Already have pkey

  return $self->db->selectcol_array(
    join( ' ',
      "SELECT {$pkey} FROM {$table} WHERE {$key} IN (",
      join( ', ', map '?', @ids ), ')' ),
    {},
    @ids
  );
}

sub _delete {
  my ( $self, $spec, $key, @ids ) = @_;

  my $table = $spec->{table};

  $self->db->do(
    [ "DELETE FROM {$table} WHERE {$key} IN (",
      join( ', ', map '?', @ids ),
      ")"
    ],
    {},
    @ids
  );
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

  my @bad = keys %bad_cols;
  if (@bad) {
    my @msg = (
      "Data has columns not found in ",
      $spec->{table}, ": ", join ', ', map "'$_'", sort @bad
    );
    $self->log->warn(@msg);
    confess @msg
     unless $self->ignore_extra_columns
     || $spec->{options}{ignore_extra_columns};
  }

  my @missing = sort keys %missing_cols;
  confess "Data lacks columns found in ", $spec->{table}, ": ",
   join( ', ', map "'$_'", @missing )
   if @missing;
}

sub _insert {
  my ( $self, $spec, @docs ) = @_;

  my $table = $spec->{table};
  my @cols  = $self->db->settable_columns_for($table);

  my $vals = join '', '(', join( ', ', map '?', @cols ), ')';
  my $sql = join ' ',
   "INSERT INTO {$table} (", join( ', ', map { "{$_}" } @cols ),
   ") VALUES", join( ', ', ($vals) x @docs );

  my %is_json = map { $_ => 1 } @{ $spec->{json} // [] };
  my @bind = ();
  for my $doc (@docs) {
    for my $col (@cols) {
      my $val = $doc->{$col};
      push @bind, $is_json{$col} ? $self->json_encode($val) : $val;
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
         // confess "Can't save a kind with no primary key";

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
  $self->log->debug( "load $kind: ", join ", ", @ids );
  my $spec   = $self->spec_for_root($kind);
  my $pkey   = $spec->{pkey};
  my $docs   = $self->_load_deep( $spec, $pkey, @ids );
  my $by_key = $self->db->stash_by( $docs, $pkey );
  my $res    = [map { ( $by_key->{$_} // [] )->[0] } @ids];
  $self->emit( 'load', $kind, \@ids, $res );
  return $res;
}

sub deepen {
  my ( $self, $kind, $docs ) = @_;
  $self->log->debug( "deepen $kind: ", scalar(@$docs), " objects" );
  return $self->_deepen( $self->spec_for_root($kind), dclone $docs );
}

sub query {
  my ( $self, $kind, $sql, @bind ) = @_;
  my $docs = $self->db->selectall_arrayref( $sql, { Slice => {} }, @bind );
  $self->log->debug( "query $kind: ",
    $sql, " (", join( ", ", @bind ), ")" );
  my $res = $self->_deepen( $self->spec_for_root($kind), $docs );
  $self->emit( 'query', $kind, $sql, \@bind, $res );
  return $res;
}

sub load_by_key {
  my ( $self, $kind, $key, @ids ) = @_;
  $self->log->debug( "load_by_key $kind:", join ", ", $key, @ids );
  return $self->_load_deep( $self->spec_for($kind), $key, @ids );
}

sub delete {
  my ( $self, $kind, @ids ) = @_;
  $self->log->debug( "delete $kind: ", join ", ", @ids );
  my $spec = $self->spec_for_root($kind);
  confess "Can't delete: schema is append only" if $spec->{append};
  $self->emit( 'delete', $kind, \@ids );
  $self->_delete_deep( $spec, $spec->{pkey}, @ids );
}

sub _only_once {
  my ( $self, @ids ) = @_;
  my %seen = ();
  $seen{$_}++ for @ids;
  my @multi = grep { $seen{$_} > 1 } keys %seen;
  confess "These ids appeared more than once: ", join( ', ', @multi )
   if @multi;
}

sub save {
  my ( $self, $kind, @docs ) = @_;

  my $spec = $self->spec_for_root($kind);
  my $pkey = $spec->{pkey};

  my @ids = map { $_->{$pkey} } @docs;
  $self->log->debug( "save $kind: ", join ", ", @ids );

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
