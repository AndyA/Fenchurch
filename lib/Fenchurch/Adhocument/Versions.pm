package Fenchurch::Adhocument::Versions;

our $VERSION = "1.00";

use Moose;
use Moose::Util::TypeConstraints;

use Carp qw( croak confess );
use DateTime::Format::MySQL;
use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument;
use Fenchurch::Event::Emitter;
use Storable qw( freeze );

has numify => (
  is       => 'ro',
  isa      => 'Bool',
  required => 1,
  default  => 0
);

has table => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => ':versions'
);

has _engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_engine',
  handles =>
   ['load', 'load_by_key', 'exists', Fenchurch::Event::Emitter->interface]
);

has _version_engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_version_engine'
);

with 'Fenchurch::Core::Role::DB', 'Fenchurch::Adhocument::Role::Schema',
 'Fenchurch::Core::Role::JSON', 'Fenchurch::Core::Role::NodeName',
 'Fenchurch::Core::Role::UUIDFactory';

=head1 NAME

Fenchurch::Adhocument::Versions - Versioned documents

=cut

sub _b_engine {
  my $self = shift;
  return Fenchurch::Adhocument->new(
    db     => $self->db,
    schema => $self->schema,
    numify => $self->numify,
  );
}

sub version_schema {
  my ( $self, $table, %extra ) = @_;
  return {
    version => {
      table => $self->db->table($table),
      pkey  => 'uuid',
      order => '+sequence',
      json  => ['old_data', 'new_data', 'schema'],
      %extra
    } };
}

sub _b_version_engine {
  my $self = shift;
  return Fenchurch::Adhocument->new(
    db     => $self->db,
    schema => Fenchurch::Adhocument::Schema->new(
      schema => $self->version_schema( $self->table, append => 1 )
    ),
    numify => 1
  );
}

sub _eq {
  my ( $self, $a, $b ) = @_;
  return 1 unless defined $a || defined $b;
  return 0 unless defined $a && defined $b;
  my $json = $self->_json;
  return $json->encode($a) eq $json->encode($b);
}

sub _only_changed {
  my ( $self, $pkey, $old_docs, @docs ) = @_;
  my @out = ();

  for my $doc (@docs) {
    my $pk  = $doc->{$pkey};
    my $old = $old_docs->{$pk}[0];
    next if $self->_eq( $old, $doc, $pk );
    push @out, $doc;
  }

  return @out;
}

sub _ver_sequence {
  my ( $self, @ids ) = @_;

  return {} unless @ids;

  my $table = $self->table;

  my $sql = $self->db->quote_sql(
    "SELECT {object}, MAX({sequence}) AS {sequence}",
    "FROM {$table}",
    "WHERE {object} IN (",
    join( ", ", map "?", @ids ),
    ")",
    "GROUP BY {object}"
  );

  return $self->db->group_by(
    $self->dbh->selectall_arrayref( $sql, { Slice => {} }, @ids ),
    'object' );
}

sub _last_leaf {
  my $self = shift;

  my $table = $self->table;

  my ($leaf) = $self->dbh->selectrow_array(
    $self->db->quote_sql(
      "SELECT {uuid}",
      "FROM {$table}",
      "ORDER BY {serial} DESC",
      "LIMIT 1"
    )
  );

  return $leaf;
}

sub _build_versions {
  my ( $self, $options, $edits, $kind, $old_docs, @docs ) = @_;

  my $seq    = $self->_ver_sequence( map { $_->[0] } @docs );
  my $schema = $self->schema_for($kind);
  my $when   = DateTime::Format::MySQL->format_datetime( $options->{when}
     // DateTime->now );
  my @el  = @$edits;
  my @ver = ();

  for my $doc (@docs) {
    my ( $oid, $new_data ) = @$doc;
    my $sn = ( $seq->{$oid}[0]{sequence} // 0 ) + 1;
    my %edit = %{ shift @el };
    delete $edit{serial};
    push @ver,
     {%edit,
      rand     => rand(),
      object   => $oid,
      when     => $when,
      sequence => $sn,
      kind     => $kind,
      schema   => $schema,
      old_data => $old_docs->{$oid}[0],
      new_data => $new_data,
     };
  }
  return @ver;
}

sub _save_versions {
  my $self = shift;
  my @ver  = $self->_build_versions(@_);
  $self->_version_engine->save( version => @ver );
  $self->emit( 'version', \@ver );
}

sub _edit_factory {
  my ( $self, $options, $count ) = @_;

  my @parents = @{ $options->{parents} || [] };
  my @uuids   = @{ $options->{uuid}    || [] };

  if ( @parents < $count ) {
    my $leaf = $self->_last_leaf;
    push @parents, ($leaf) x ( $count - @parents );
  }

  my $node = $self->node_name;

  return [
    map {
      { uuid => shift(@uuids) // $self->_make_uuid,
        parent => shift(@parents),
        node   => $node
      }
    } 1 .. $count
  ];
}

sub _old_docs {
  my ( $self, $options, $kind, @ids ) = @_;
  my $pkey = $self->pkey_for($kind);

  my $old_docs = $self->load( $kind, @ids );

  if ( $options->{expect} ) {
    my $expect = $options->{expect};

    my $doc_count    = scalar @$old_docs;
    my $expect_count = scalar @$expect;

    die "Document / expectation count mismatch ",
     "($doc_count versus $expect_count)"
     unless $doc_count == $expect_count;

    for my $idx ( 0 .. $doc_count - 1 ) {
      my $doc = $expect->[$idx];
      my $old = $old_docs->[$idx];
      unless ( $self->_eq( $doc, $old ) ) {
        $self->emit( 'conflict', $kind, $old, $doc, $options->{context} );
        if ( $self->do_default ) {
          my $id = ( $doc && $doc->{$pkey} ) // ( $old && $old->{$pkey} );
          die "Document [$id] doesn't match expectation";
        }
      }
    }
  }

  return $self->db->stash_by( $old_docs, $pkey );
}

sub _save {
  my ( $self, $options, $edits, $kind, @docs ) = @_;

  my $pkey     = $self->pkey_for($kind);
  my @ids      = map { $_->{$pkey} } @docs;
  my $old_docs = $self->_old_docs( $options, $kind, @ids );
  my @dirty    = $self->_only_changed( $pkey, $old_docs, @docs );

  $self->_engine->save( $kind, @dirty );
  $self->_save_versions( $options, $edits, $kind, $old_docs,
    map { [$_->{$pkey}, $_] } @dirty );
}

sub _delete {
  my ( $self, $options, $edits, $kind, @ids ) = @_;

  my $pkey     = $self->pkey_for($kind);
  my @eids     = @{ $self->exists( $kind => @ids ) };
  my $old_docs = $self->_old_docs( $options, $kind, @eids );

  $self->_engine->delete( $kind, @eids );
  $self->_save_versions( $options, $edits, $kind, $old_docs,
    map { [$_, undef] } @eids );
}

sub _save_or_delete {
  my $self = shift;
  my $save = shift;

  my $options = ref $_[0] ? shift : {};
  my ( $kind, @things ) = @_;

  $self->transaction(
    sub {
      my $edits = $self->_edit_factory( $options, scalar(@things) );
      if ($save) { $self->_save( $options, $edits, $kind, @things ) }
      else       { $self->_delete( $options, $edits, $kind, @things ) }
    }
  );
}

sub save   { shift->_save_or_delete( 1, @_ ) }
sub delete { shift->_save_or_delete( 0, @_ ) }

sub _unpack_version {
  my ( $self, $ver ) = @_;
  my $doc = delete $ver->{old_data};
  return ( $ver, $doc );
}

sub _unpack_versions {
  my ( $self, $kind, $doc, $versions ) = @_;
  my @meta = ();
  my @docs = ();
  for my $ver (@$versions) {
    my ( $meta, $vdoc ) = $self->_unpack_version($ver);
    push @meta, $meta;
    push @docs, $vdoc;
  }
  push @docs, $doc;
  unshift @meta, { sequence => 0, kind => $kind };
  my @out = ();
  push @out, { meta => shift @meta, doc => shift @docs } while @docs;
  return \@out;
}

sub versions {
  my ( $self, $kind, @ids ) = @_;

  # Load matching documents...
  my $docs = $self->db->stash_by( $self->load( $kind, @ids ),
    $self->pkey_for($kind) );

  # ...and version history
  my $vers
   = $self->db->stash_by(
    $self->_version_engine->load_by_key( 'version', 'object', @ids ),
    'object' );

  return [
    map {
      $self->_unpack_versions(
        $kind,
        ( $docs->{$_} // [] )->[0],
        $vers->{$_} // []
       )
    } @ids
  ];
}

=head2 C<load_versions>

Load versions by UUID.

=cut

sub load_versions {
  my ( $self, @ids ) = @_;
  return $self->_version_engine->load( version => @ids );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
