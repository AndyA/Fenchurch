package Fenchurch::Syncotron::Engine;

use v5.10;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1,
  handles => ['db', 'dbh'],
);

has _pending_engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_pending_engine'
);

=head1 NAME

Fenchurch::Syncotron::Engine - The guts of the sync engine

=cut

sub _b_pending_engine {
  my $self = shift;
  return Fenchurch::Adhocument->new(
    db     => $self->db,
    schema => Fenchurch::Adhocument::Schema->new(
      schema => $self->versions->version_schema(":pending")
    ),
    numify => 1
  );
}

=head2 C<serial>

Get the current serial number

=cut

sub serial {
  my $self = shift;

  my ($serial)
   = $self->dbh->selectrow_array(
    $self->db->quote_sql("SELECT MAX({serial}) FROM {:versions}") );

  return $serial // 0;
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

=head2 C<recent>

Return a structure describing changes since the specified serial
number.

=cut

sub _recent {
  my ( $self, $serial, $limit ) = @_;

  return $self->dbh->selectall_arrayref(
    $self->db->quote_sql(
      "SELECT {uuid}, {serial} FROM {:versions}",
      ( defined $serial
        ? ("WHERE {serial} > ?")
        : ()
      ),
      "ORDER BY {serial} ASC",
      ( defined $limit ? ("LIMIT ?") : () )
    ),
    { Slice => {} },
    grep defined,
    $serial, $limit
  );
}

sub recent {
  my ( $self, $serial, $limit ) = @_;

  my $recent = $self->_recent( $serial, $limit );
  my $next = @$recent ? $recent->[-1]{serial} : $serial;
  return {
    recent => [map { $_->{uuid} } @$recent],
    serial => $next
  };
}

=head2 C<since>

Return the IDs of changes subsequent to a specific serial.

=cut

sub since {
  my ( $self, $serial, $limit ) = @_;

  my $recent = $self->_recent( $serial, $limit );
  return map { $_->{uuid} } @$recent;
}

sub _have {
  my ( $self, $tbl, @uuid ) = @_;
  return () unless @uuid;
  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {uuid} FROM {$tbl} WHERE {uuid} IN (",
        join( ", ", map "?", @uuid ), ")"
      ),
      {},
      @uuid
    ) };
}

=head2 C<dont_have>

Given a list of change UUIDs return those that we don't already have

=cut

sub dont_have {
  my ( $self, @uuid ) = @_;

  my %need = map { $_ => 1 } @uuid;

  for my $tbl ( ":versions", ":pending" ) {
    my @got = $self->_have( $tbl, keys %need );
    delete $need{$_} for @got;
  }

  return grep { $need{$_} } @uuid;
}

=head2 C<want>

Return a list of versions that we need.

=cut

sub want {
  my ( $self, $start, $size ) = @_;
  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT DISTINCT {p1.parent}",
        "  FROM {:pending} AS {p1}",
        "  LEFT JOIN {:pending} AS {p2}",
        "    ON {p1.parent} = {p2.uuid}",
        " WHERE {p2.uuid} IS NULL",
        " ORDER BY {p1.serial} ASC",
        " LIMIT ?, ?"
      ),
      {},
      $start, $size
    ) };
}

sub _find_ready {
  my $self = shift;
  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {p.uuid}",
        "  FROM {:pending} AS {p}",
        " WHERE {p.parent} IS NULL",
        "UNION SELECT {p.uuid}",
        "  FROM {:pending} AS {p}, {:versions} AS {v}",
        " WHERE {p.parent} = {v.uuid}"
      )
    ) };
}

sub _flush_pending {
  my $self = shift;

  # Process pending edits that either have a NULL parent or a parent
  # that is already applied.

  my @ready = $self->_find_ready;
  return 0 unless @ready;

  my $pe = $self->_pending_engine;
  my $ve = $self->versions;

  my $changes = $pe->load( version => @ready );

  for my $ch (@$changes) {
    my @args = (
      { uuid    => [$ch->{uuid}],
        parents => [$ch->{parent}],
        expect  => [$ch->{old_data}]
      },
      $ch->{kind}
    );

    if ( defined $ch->{new_data} ) { $ve->save( @args, $ch->{new_data} ) }
    else                           { $ve->delete( @args, $ch->{object} ) }
  }

  $pe->delete( version => @ready );

  return scalar(@ready);
}

=head2 C<add_versions>

Add a list of versions to those that we know about. If the versions
are satisifed (i.e. we already have their parents) they will be applied
immediately otherwise they will be held in the pending table until they
have been satisfied.

=cut

sub add_versions {
  my ( $self, @vers ) = @_;

  my %need = map { $_ => 1 } $self->dont_have( map { $_->{uuid} } @vers );

  my @new = ();
  for my $ver (@vers) {
    next unless $need{ $ver->{uuid} };
    my $nv = {%$ver};    # Shallow
    delete $nv->{serial};
    push @new, $nv;
  }

  my $pe = $self->_pending_engine;

  # Mark them all pending
  $pe->save( version => @new );

  # Flush any pending versions that are now complete.
  $self->db->transaction( sub { 1 while ( $self->_flush_pending ) } );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
