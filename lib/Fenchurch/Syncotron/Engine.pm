package Fenchurch::Syncotron::Engine;

use v5.10;

our $VERSION = "1.00";

use Moose;
use Moose::Util::TypeConstraints;

use Time::HiRes qw( time );

has timeout => (
  is      => 'ro',
  isa     => 'Num',
  default => 600
);

has _pending_engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_pending_engine'
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

  return $self->db->selectcol_array(
    [ "SELECT {tc1.uuid}",
      "  FROM {:versions} AS {tc1}",
      "  LEFT JOIN {:versions} AS {tc2} ON {tc2.parent} = {tc1.uuid}",
      " WHERE {tc2.parent} IS NULL",
      " ORDER BY {tc1.serial} ASC",
      " LIMIT ?, ?"
    ],
    {},
    $start, $size
  );
}

=head2 C<random>

Return a random sample of nodes.

=cut

sub random {
  my ( $self, $start, $size ) = @_;

  return $self->db->selectcol_array(
    [ "SELECT {uuid}",
      "  FROM {:versions}",
      " ORDER BY {rand} ASC",
      " LIMIT ?, ?"
    ],
    {},
    $start, $size
  );
}

=head2 C<sample>

Return a random sample of non-leaf nodes.

=cut

sub sample {
  my ( $self, $start, $size ) = @_;

  return $self->db->selectcol_array(
    [ "SELECT DISTINCT {tc1.uuid}",
      "  FROM {:versions} AS {tc1}, {:versions} AS {tc2}",
      " WHERE {tc2.parent} = {tc1.uuid}",
      " ORDER BY {tc1.rand} ASC",
      " LIMIT ?, ?"
    ],
    {},
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
  return $self->db->selectcol_array(
    [ "SELECT {uuid} FROM {$tbl} WHERE {uuid} IN (",
      join( ", ", map "?", @uuid ), ")"
    ],
    {},
    @uuid
  );
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

=head2 C<known>

Add UUIDs of known versions

=cut

sub known {
  my ( $self, @uuid ) = @_;

  my @known = $self->dont_have(@uuid);
  return unless @known;

  $self->db->do(
    ["REPLACE INTO {:known} ({uuid}) VALUES ", join ", ", map "(?)", @known],
    {}, @known
  );
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
  return $self->db->selectcol_array(
    [ "SELECT DISTINCT {uuid} FROM (",
      "  SELECT {uuid} FROM {:known}",
      "  UNION SELECT {p1.parent} AS {uuid}",
      "    FROM {:pending} AS {p1}",
      "    LEFT JOIN {:pending} AS {p2}",
      "      ON {p1.parent} = {p2.uuid}",
      "   WHERE {p2.uuid} IS NULL",
      ") AS {q}",
      " LIMIT ?, ?"
    ],
    {},
    $start, $size
  );
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

sub _flush_pending {
  my $self = shift;

  # Process pending edits that either have a NULL parent or a parent
  # that is already applied.

  # TODO it's possible to process versions in the pending queue
  # that have parents also in pending.

  my @ready = $self->_find_ready;
  return 0 unless @ready;

  my $pe = $self->_pending_engine;
  my $ve = $self->versions;

  my $changes = $pe->load( version => @ready );

  $self->emit( flush_pending => $changes );

  for my $ch (@$changes) {
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

  $pe->delete( version => @ready );

  return scalar(@ready);
}

sub flush_pending {
  my ( $self, $timeout ) = @_;

  my $done = $self->lock( key => "sync" )->locked(
    $timeout,
    sub {
      my $deadline = time + $timeout;
      while ( time < $deadline ) {
        return unless $self->_flush_pending;
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

  my $done = $self->lock( key => "sync" )->locked(
    $self->timeout,
    sub {
      my @uuid = map { $_->{uuid} } @vers;
      $self->_unknown(@uuid);
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
    }
  );

  die "Timeout while waiting for lock" unless $done;
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
