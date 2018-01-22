package Fenchurch::Syncotron::Engine;

our $VERSION = "1.00";

use Fenchurch::Moose;
use Moose::Util::TypeConstraints;

use Time::HiRes qw( time );

has _pending_engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_pending_engine'
);

has _recent_cache => (
  is      => 'ro',
  isa     => 'ArrayRef',
  default => sub { [] }
);

with qw(
 Fenchurch::Syncotron::Role::Versions
 Fenchurch::Event::Role::Emitter
 Fenchurch::Core::Role::Lock
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
   = $self->db->selectrow_array("SELECT MAX({serial}) FROM {:versions}");

  return $serial // 0;
}

=head2 C<leaves>

Return a page of the leaf nodes of the version tree.

=cut

sub leaves {
  my ( $self, $start, $size ) = @_;

  return $self->db->selectall_array(
    [ "SELECT {tc1.uuid}, {tc1.serial}",
      "  FROM {:versions} AS {tc1}",
      "  LEFT JOIN {:versions} AS {tc2} ON {tc2.parent} = {tc1.uuid}",
      " WHERE {tc2.parent} IS NULL",
      " ORDER BY {tc1.serial} ASC",
      " LIMIT ?, ?"
    ],
    { Slice => {} },
    $start, $size
  );
}

=head2 C<random>

Return a random sample of nodes.

=cut

sub random {
  my ( $self, $start, $size ) = @_;

  return $self->db->selectall_array(
    [ "SELECT {uuid}, {serial}",
      "  FROM {:versions}",
      " ORDER BY {rand} ASC",
      " LIMIT ?, ?"
    ],
    { Slice => {} },
    $start, $size
  );
}

=head2 C<sample>

Return a random sample of non-leaf nodes.

=cut

sub sample {
  my ( $self, $start, $size ) = @_;

  return $self->db->selectall_array(
    [ "SELECT DISTINCT {tc1.uuid}, {tc1.serial}",
      "  FROM {:versions} AS {tc1}, {:versions} AS {tc2}",
      " WHERE {tc2.parent} = {tc1.uuid}",
      " ORDER BY {tc1.rand} ASC",
      " LIMIT ?, ?"
    ],
    { Slice => {} },
    $start, $size
  );
}

=head2 C<recent>

Return a structure describing changes since the specified serial
number.

=cut

sub _recent {
  my ( $self, $serial, $limit ) = @_;

  return $self->db->selectall_arrayref(
    [ "SELECT {uuid}, {serial} FROM {:versions}",
      ( defined $serial
        ? ("WHERE {serial} > ?")
        : ()
      ),
      "ORDER BY {serial} ASC",
      ( defined $limit ? ("LIMIT ?") : () )
    ],
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
    recent => $recent,
    serial => $next
  };
}

=head2 C<since>

Return the IDs of changes subsequent to a specific serial.

=cut

sub since {
  my ( $self, $serial, $limit ) = @_;

  my $recent = $self->_recent( $serial, $limit );
  return @$recent;
}

sub _have {
  my ( $self, $tbl, @uuid ) = @_;
  return () unless @uuid;
  return $self->db->selectcol_array(
    [ "SELECT {uuid} FROM {$tbl} WHERE {uuid} IN (",
      join( ", ", map "?", @uuid ), ")"
    ],
    {},
    @uuid
  );
}

sub _dont_have {
  my ( $self, $tbls, @uuid ) = @_;

  return () unless @uuid;

  my %need = map { $_ => 1 } grep defined, @uuid;

  for my $tbl (@$tbls) {
    my @got = $self->_have( $tbl, keys %need );
    delete @need{@got};
    last unless keys %need;
  }

  return grep { $need{$_} } grep defined, @uuid;
}

=head2 C<dont_have>

Given a list of change UUIDs return those that we don't already have in versions or pending.

=cut

sub dont_have {
  shift->_dont_have( [":pending", ":versions"], @_ );
}

=head2 C<dont_have_versions>

Given a list of change UUIDs return those that we don't already have in versions.

=cut

sub dont_have_versions {
  shift->_dont_have( [":versions"], @_ );
}

sub _coerce_to_v2 {
  my ( $self, @list ) = @_;
  return map { ref $_ ? $_ : { uuid => $_, serial => 0 } }
   grep { defined } @list;
}

=head2 C<known>

Add to known versions

=cut

sub known {
  my ( $self, @list ) = @_;

  # Transitional hack
  my @ver = $self->_coerce_to_v2(@list);
  my @uuid = map { $_->{uuid} } @ver;

  my %want = map { $_ => 1 } $self->dont_have(@uuid);
  my @need = grep { $want{ $_->{uuid} } } @ver;
  $self->db->replace( ':known', @need );
}

sub _unknown {
  my ( $self, @uuid ) = @_;

  return unless @uuid;

  $self->db->do(
    [ "DELETE FROM {:known} WHERE {uuid} IN (",
      join( ", ", map "?", @uuid ),
      ")"
    ],
    {},
    @uuid
  );
}

=head2 C<want>

Return a list of versions that we need.

=cut

sub want {
  my ( $self, $start, $size ) = @_;

  die "Non-zero start not supported"
   unless $start == 0;

  my @known
   = $self->db->selectcol_array(
    ["SELECT {uuid} FROM {:known} ORDER BY {serial} LIMIT ?, ?"],
    {}, $start, $size );

  return @known if @known;

  my @want = $self->db->selectcol_array(
    [ "SELECT DISTINCT {p1.parent} AS {uuid}",
      "  FROM {:pending} AS {p1}",
      "  LEFT JOIN {:pending} AS {p2}",
      "    ON {p1.parent} = {p2.uuid}",
      " WHERE {p2.uuid} IS NULL",
      " ORDER BY {p1.serial}",
      " LIMIT ?, ?"
    ],
    {},
    $start, $size
  );

  return $self->dont_have_versions(@want);
}

sub _find_ready {
  my $self = shift;
  return $self->db->selectcol_array(
    [ "SELECT {p.uuid}",
      "  FROM {:pending} AS {p}",
      " WHERE {p.parent} IS NULL",
      "UNION SELECT {p.uuid}",
      "  FROM {:pending} AS {p}, {:versions} AS {v}",
      " WHERE {p.parent} = {v.uuid}"
    ]
  );
}

sub _find_by_parent {
  my ( $self, @uuid ) = @_;
  return unless @uuid;
  return $self->db->selectcol_array(
    [ "SELECT {uuid} FROM {:pending} WHERE {parent} IN (",
      join( ", ", map "?", @uuid ), ")"
    ],
    {},
    @uuid
  );
}

sub _flush_pending {
  my ($self) = @_;

  my $pe     = $self->_pending_engine;
  my $recent = $self->_recent_cache;

  # Process pending edits that either have a NULL parent or a parent
  # that is already applied.

  my @ready = $self->_find_by_parent( splice @$recent );
  @ready = $self->_find_ready unless @ready;

  my @need = $self->dont_have_versions(@ready);
  if (@need) {

    my $ve = $self->versions;

    my $changes = $pe->load( version => @need );

    $self->emit( flush_pending => $changes );

    for my $ch (@$changes) {
      push @$recent, $ch->{uuid};
      my @args = (
        { uuid       => [$ch->{uuid}],
          parents    => [$ch->{parent}],
          expect     => [$ch->{old_data}],
          force_save => 1
        },
        $ch->{kind}
      );

      if ( defined $ch->{new_data} ) { $ve->save( @args, $ch->{new_data} ) }
      elsif ( defined $ch->{old_data} ) { $ve->delete( @args, $ch->{object} ) }
      else {
        delete $ch->{serial};
        $ve->version_engine->save( version => $ch );
      }
    }
  }

  $pe->delete( version => @ready );

  return scalar(@ready);
}

sub flush_pending {
  my ( $self, $lock_timeout, $work_timeout ) = @_;

  $work_timeout //= $lock_timeout;

  my $done = $self->lock( key => "sync" )->locked(
    $lock_timeout,
    sub {
      my $deadline = time + $work_timeout;
      while ( time < $deadline ) {
        my $done = $self->_flush_pending;
        last unless $done;
      }
    }
  );
}

=head2 C<add_versions>

Add a list of versions to those that we know about. If the versions
are satisifed (i.e. we already have their parents) they will be applied
immediately otherwise they will be held in the pending table until they
have been satisfied.

=cut

sub add_versions {
  my ( $self, @vers ) = @_;

  my @uuid = map { $_->{uuid} } @vers;
  my %need = map { $_ => 1 } $self->dont_have(@uuid);

  my @new = ();
  for my $ver (@vers) {
    next unless $need{ $ver->{uuid} };
    my $nv = {%$ver};    # Shallow
    delete $nv->{serial};
    push @new, $nv;
  }

  my $pe = $self->_pending_engine;

  $self->emit( add_versions => \@new );

  # Mark them all pending
  $pe->save( version => @new );

  # And, when saved, as not needed
  $self->_unknown(@uuid);
}

=head2 C<statistics>

Get some statistics about sync.

=cut

sub statistics {
  my $self = shift;

  my $stats = $self->db->selectall_arrayref(
    join( " UNION ",
      map { "SELECT '$_' AS {table}, COUNT(*) AS {count} FROM {:$_}" }
       qw( pending known versions ) ),
    { Slice => {} }
  );

  my $out = {};
  for my $row (@$stats) {
    $out->{ $row->{table} } = 1 * $row->{count};
  }

  return $out;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
