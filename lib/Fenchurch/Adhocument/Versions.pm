package Fenchurch::Adhocument::Versions;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;

use Carp qw( croak confess );
use DateTime::Format::MySQL;
use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument;
use Fenchurch::Event::Emitter;
use Storable qw( freeze );
use UUID::Tiny ':std';

with 'Fenchurch::Core::Role::DB', 'Fenchurch::Adhocument::Role::Schema',
 'Fenchurch::Core::Role::JSON', 'Fenchurch::Core::Role::NodeName';

has disable_checks => ( is => 'ro', isa => 'Bool', default => 0 );

has numify => (
  is       => 'ro',
  isa      => 'Bool',
  required => 1,
  default  => 0
);

has conflict_resolver => (
  is       => 'ro',
  isa      => duck_type( ['resolve'] ),
  required => 1,
  lazy     => 1,
  default  => sub { shift }
);

has _engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_engine',
  handles => ['load', 'exists', Fenchurch::Event::Emitter->interface]
);

has _version_engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_version_engine'
);

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

sub _version_schema {
  my ( $self, %extra ) = @_;
  return {
    version => {
      table  => $self->db->table(":versions"),
      pkey   => 'uuid',
      order  => '+sequence',
      append => 1,                                    # Disable deletions
      json   => ['old_data', 'new_data', 'schema'],
      %extra
    } };
}

sub _b_version_engine {
  my $self = shift;
  return Fenchurch::Adhocument->new(
    db => $self->db,
    schema =>
     Fenchurch::Adhocument::Schema->new( schema => $self->_version_schema ),
    numify => 1
  );
}

sub _eq {
  my ( $self, $a, $b ) = @_;
  my $json = $self->_json;
  return 1 unless defined $a || defined $b;
  return 0 unless defined $a && defined $b;
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

  my $sql = $self->db->quote_sql(
    "SELECT {object}, MAX({sequence}) AS {sequence}",
    "FROM {:versions}",
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

  my ($leaf) = $self->dbh->selectrow_array(
    $self->db->quote_sql(
      "SELECT {uuid}",
      "FROM {:versions}",
      "ORDER BY {serial} DESC",
      "LIMIT 1"
    )
  );

  return $leaf;
}

sub _make_uuid { create_uuid_as_string(UUID_V4) }

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
  my ( $self, $count, @parents ) = @_;

  if ( @parents < $count ) {
    my $leaf = $self->_last_leaf;
    push @parents, ($leaf) x ( $count - @parents );
  }

  my $node = $self->node_name;

  return [
    map {
      { uuid   => $self->_make_uuid,
        parent => shift(@parents),
        node   => $node
      }
    } 1 .. $count
  ];
}

sub _old_docs {
  my ( $self, $options, $kind, @ids ) = @_;
  my $pkey = $self->pkey_for($kind);
  my $old_docs = $self->db->stash_by( $self->load( $kind, @ids ), $pkey );

  if ( $options->{expect} ) {
    for my $doc ( @{ $options->{expect} } ) {
      my $old = $old_docs->{ $doc->{$pkey} }[0];
      unless ( $self->_eq( $doc, $old ) ) {
        $self->emit( 'conflict', $kind, $old, $doc );
        if ( $self->do_default ) {
          my $id = ( $doc && $doc->{$pkey} ) // ( $old && $old->{$pkey} );
          die "Document [$id] doesn't match expectation";
        }
      }
    }
  }

  return $old_docs;
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

  my @parents = @{ $options->{parents} || [] };

  $self->transaction(
    sub {
      my $edits = $self->_edit_factory( scalar(@things), @parents );
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

# Stub implentation of conflict resolver

sub resolve { die "Current data doesn't match edit's expectations" }

# Sync support. Get changes from the global list, apply them.
# TODO refactor this to use expectations

sub _apply_edit {
  my ( $self, $index, $edit ) = @_;
  unless ( $self->disable_checks ) {
    die "Out of order serial number ($index >= $edit->{serial})"
     unless $index < $edit->{serial};

    my $old = $self->load( $edit->{kind}, $edit->{object} );

    $self->conflict_resolver->resolve( $edit, $old )
     unless $self->_json->encode( [$edit->{old_data}] ) eq
     $self->_json->encode($old);
  }

  if ( defined $edit->{new_data} ) {
    $self->_save( {}, [$edit], $edit->{kind}, $edit->{new_data} );
  }
  else {
    $self->_delete( {}, [$edit], $edit->{kind}, $edit->{object} );
  }
}

sub _find_edits {
  my ( $self, @ids ) = @_;

  return [] unless @ids;

  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {uuid} FROM {:versions}",
        "WHERE {uuid} IN (",
        join( ", ", ("?") x @ids ),
        ")"
      ),
      {},
      @ids
    ) };
}

sub _versions_for_schema {
  my ( $self, $schema ) = @_;

  my $scm = Fenchurch::Adhocument::Schema->new(
    schema => $schema,
    db     => $self->db
  );

  return Fenchurch::Adhocument::Versions->new(
    schema            => $scm,
    db                => $self->db,
    disable_checks    => $self->disable_checks,
    conflict_resolver => $self->conflict_resolver
  );
}

=head2 C<apply>

Apply a serialised set of changes. Returns the index to be used for the next
call to C<since>.

  my $index = 0;
  while () {
    my $stash = $ver_in->since($index, 10);
    unless (@$stash) {
      sleep 1;
      next;
    }
    $index = $ver_out->apply($index, $stash);
  }

=cut

sub apply {
  my ( $self, $index, $stash ) = @_;

  my %cache = ();

  # UUIDs of incoming edits
  my @eids = map { $_->{uuid} } @$stash;

  # Edits that we've already seen
  my %seen = map { $_ => 1 } $self->_find_edits(@eids);

  for my $edit (@$stash) {
    unless ( $seen{ $edit->{uuid} } ) {
      # Build a suitable schema
      my $ver = $cache{ $self->_json->encode( $edit->{schema} ) } //=
       $self->_versions_for_schema( $edit->{schema} );

      # Apply the edit
      $ver->_apply_edit( $index, $edit );
    }
    $index = $edit->{serial};
  }

  return $index;
}

=head2 C<serial>

Get the current serial number

=cut

sub serial {
  my $self = shift;

  my ($serial)
   = $self->dbh->selectrow_array(
    $self->db->quote_sql("SELECT MAX({serial}) FROM {:versions}") );

  return $serial;
}

=head2 C<leaves>

Return a page of the leaf nodes of the version tree.

=cut

sub leaves {
  my ( $self, $start, $size ) = @_;

  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {tc1.uuid}",
        "FROM {:versions} AS {tc1}",
        "LEFT JOIN {:versions} AS {tc2} ON {tc2.parent} = {tc1.uuid}",
        "WHERE {tc2.parent} IS NULL",
        "ORDER BY {tc1.serial} ASC",
        "LIMIT ?, ?"
      ),
      {},
      $start, $size
    ) };
}

=head2 C<sample>

Return a random sample of nodes.

=cut

sub sample {
  my ( $self, $start, $size ) = @_;

  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {tc1.uuid}",
        "FROM {:versions} AS {tc1}, {:versions} AS {tc2}",
        "WHERE {tc2.parent} = {tc1.uuid}",
        "ORDER BY {tc1.rand} ASC",
        "LIMIT ?, ?"
      ),
      {},
      $start, $size
    ) };
}

sub _expand_versions {
  my ( $self, $vers ) = @_;

  for my $row (@$vers) {
    $row->{$_} = $self->_json->decode( $row->{$_} )
     for qw( schema old_data new_data );
  }

  return $vers;
}

=head2 C<load_versions>

Load versions by UUID.

=cut

sub load_versions {
  my ( $self, @ids ) = @_;
  return $self->_version_engine->load( version => @ids );
}

=head2 C<since>

Return a stash of changes subsequent to the specified change. The resulting
stash may be replayed using C<apply>.

  my $stash = $ver->since(0, 10);

=cut

sub since {
  my ( $self, $index, $limit ) = @_;

  my $rc = $self->dbh->selectall_arrayref(
    $self->db->quote_sql(
      "SELECT * FROM {:versions}",
      ( defined $index
        ? ("WHERE {serial} > ?")
        : ()
      ),
      "ORDER BY {serial} ASC",
      ( defined $limit ? ("LIMIT ?") : () )
    ),
    { Slice => {} },
    grep defined,
    $index, $limit
  );

  return $self->_expand_versions($rc);
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
