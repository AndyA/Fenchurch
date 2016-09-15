package Fenchurch::Adhocument::Versions;

use Moose;
use Moose::Util::TypeConstraints;

use Carp qw( croak confess );
use DateTime::Format::MySQL;
use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument;
use Fenchurch::Event::Emitter;
use Storable qw( freeze );
use Sys::Hostname;
use UUID::Tiny ':std';

with 'Fenchurch::Core::Role::DB';
with 'Fenchurch::Adhocument::Role::Schema';
with 'Fenchurch::Core::Role::JSON';

has version_table => ( is => 'ro', isa => 'Str', required => 1 );

has disable_checks => ( is => 'ro', isa => 'Bool', default => 0 );

has node_name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => sub { hostname }
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
    schema => $self->schema
  );
}

sub _version_schema {
  my ( $self, %extra ) = @_;
  return {
    version => {
      table  => $self->version_table,
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
     Fenchurch::Adhocument::Schema->new( schema => $self->_version_schema )
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

  my $table = $self->db->quote_name( $self->version_table );

  my $sql = $self->db->quote_sql(
    "SELECT {object}, MAX({sequence}) AS {sequence}",
    "FROM $table",
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
  my $self  = shift;
  my $table = $self->db->quote_name( $self->version_table );

  my ($leaf) = $self->dbh->selectrow_array(
    $self->db->quote_sql(
      "SELECT {uuid}",
      "FROM $table", "ORDER BY {serial} DESC",
      "LIMIT 1"
    )
  );

  return $leaf;
}

sub _make_uuid { create_uuid_as_string(UUID_V4) }

sub _now { DateTime::Format::MySQL->format_datetime( DateTime->now ) }

sub _build_versions {
  my ( $self, $edits, $kind, $old_docs, @docs ) = @_;

  my $seq    = $self->_ver_sequence( map { $_->[0] } @docs );
  my $schema = $self->schema_for($kind);
  my $when   = $self->_now;
  my @el     = @$edits;
  my @ver    = ();

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
  # We delegate most event emitting to our engine
  $self->_engine->emit( 'version', \@ver );
}

sub _edit_factory {
  my ( $self, $count, $parent ) = @_;

  $parent //= $self->_last_leaf;
  my $node = $self->node_name;

  my @edits = ();
  for ( 1 .. $count ) {
    my $uuid = $self->_make_uuid;
    push @edits, { uuid => $uuid, parent => $parent, node => $node };
    $parent = $uuid;
  }

  return \@edits;
}

sub _save {
  my ( $self, $edits, $kind, @docs ) = @_;

  my $pkey     = $self->pkey_for($kind);
  my @ids      = map { $_->{$pkey} } @docs;
  my $old_docs = $self->db->stash_by( $self->load( $kind, @ids ), $pkey );
  my @dirty    = $self->_only_changed( $pkey, $old_docs, @docs );

  $self->_engine->save( $kind, @dirty );
  $self->_save_versions( $edits, $kind, $old_docs,
    map { [$_->{$pkey}, $_] } @dirty );
}

sub save {
  my ( $self, $kind, @docs ) = @_;
  my $edits = $self->_edit_factory( scalar @docs );
  return $self->_save( $edits, $kind, @docs );
}

sub _delete {
  my ( $self, $edits, $kind, @ids ) = @_;

  my $pkey     = $self->pkey_for($kind);
  my @eids     = @{ $self->exists( $kind => @ids ) };
  my $old_docs = $self->db->stash_by( $self->load( $kind, @eids ), $pkey );
  $self->_engine->delete( $kind, @eids );
  $self->_save_versions( $edits, $kind, $old_docs,
    map { [$_, undef] } @eids );
}

sub delete {
  my ( $self, $kind, @ids ) = @_;
  my $edits = $self->_edit_factory( scalar @ids );
  return $self->_delete( $edits, $kind, @ids );
}

sub _unpack_version {
  my ( $self, $ver ) = @_;
  my $doc = delete $ver->{old_data};
  return ( $ver, $doc );
}

sub _unpack_versions {
  my ( $self, $doc, $versions ) = @_;
  my @meta = ();
  my @docs = ();
  for my $ver (@$versions) {
    my ( $meta, $vdoc ) = $self->_unpack_version($ver);
    push @meta, $meta;
    push @docs, $vdoc;
  }
  push @docs, $doc;
  unshift @meta, { sequence => 0 };
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
      $self->_unpack_versions( ( $docs->{$_} // [] )->[0], $vers->{$_} // [] )
    } @ids
  ];
}

# Stub implentation of conflict resolver

sub resolve { die "Current data doesn't match edit's expectations" }

# Sync support. Get changes from the global list, apply them.

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
    $self->_save( [$edit], $edit->{kind}, $edit->{new_data} );
  }
  else {
    $self->_delete( [$edit], $edit->{kind}, $edit->{object} );
  }
}

sub _find_edits {
  my ( $self, @ids ) = @_;

  return [] unless @ids;

  my $table = $self->db->quote_name( $self->version_table );
  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {uuid} FROM $table",
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
    version_table     => $self->version_table,
    disable_checks    => $self->disable_checks,
    conflict_resolver => $self->conflict_resolver
  );
}

=head2 C<leaves>

Return a page of the leaf nodes of the version tree.

=cut

sub leaves {
  my ( $self, $start, $size ) = @_;

  my $table = $self->db->quote_name( $self->version_table );

  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {tc1.uuid}",
        "FROM $table AS {tc1}",
        "LEFT JOIN $table AS {tc2} ON {tc2.parent} = {tc1.uuid}",
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

  my $table = $self->db->quote_name( $self->version_table );
  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {tc1.uuid}",
        "FROM $table AS {tc1}, $table AS {tc2}",
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
  return $self->_expand_versions(
    $self->_version_engine->load( version => @ids ) );
}

=head2 C<since>

Return a stash of changes subsequent to the specified change. The resulting
stash may be replayed using C<apply>.

  my $stash = $ver->since(0, 10);

=cut

sub since {
  my ( $self, $index, $limit ) = @_;

  my $table = $self->db->quote_name( $self->version_table );
  my $rc    = $self->dbh->selectall_arrayref(
    $self->db->quote_sql(
      "SELECT * FROM $table",
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

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
