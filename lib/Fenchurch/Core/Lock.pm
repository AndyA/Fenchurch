package Fenchurch::Core::Lock;

our $VERSION = "0.01";

use Fenchurch::Moose;

use Carp qw( confess );
use Fenchurch::Util qw( unique );
use POSIX qw( uname );
use Sys::Hostname;
use Time::HiRes qw( sleep time );
use Try::Tiny;

=head1 NAME

Fenchurch::Core::Lock - A database based lock

=cut

has key => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has table => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => ":lock"
);

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::DB
 Fenchurch::Core::Role::Session
);

sub host_key {
  return join "-", $$, hostname;
}

sub _decode_host_key {
  my ( $self, $host_key ) = @_;
  return split /-/, $host_key;
}

sub _has_session {
  my $self = shift;
  return $self->db->has_column( $self->table, "session" );
}

sub _prune_old_sessions {
  my $self = shift;

  return unless $self->_has_session;

  my $table = $self->table;
  my @session = unique( $self->session, $self->session_unknown );

  $self->db->do(
    [ "DELETE FROM {$table} WHERE {session} NOT IN (",
      join( ", ", map "?", @session ), ")"
    ],
    {},
    @session
  );
}

sub _get_owner {
  my ( $self, $lock_name ) = @_;

  my $table = $self->table;

  my ($owner)
   = $self->db->selectrow_array(
    ["SELECT {locked_by} FROM {$table} WHERE {name} = ?"],
    {}, $lock_name );

  return $owner;
}

sub _with_lock {
  my ( $self, $code ) = @_;

  my $table = $self->table;

  $self->db->do("LOCK TABLES {$table} WRITE");
  my $rv = eval { $code->() };
  my $err = $@;
  $self->db->do("UNLOCK TABLES");
  die $err if $err;
  return $rv;
}

sub _process_valid {
  my ( $self, $pid ) = @_;

  if ( (uname)[0] eq "Linux" && -d "/proc" ) {
    return -d sprintf "/proc/%d", $pid;
  }

  # Fall back on kill - which also returns false if we don't
  # have permission to signal $pid
  return kill 0, $pid;
}

sub _valid_lock {
  my ( $self, $locked_by ) = @_;

  # NULL => not locked
  return unless defined $locked_by;

  # Locked by whom?
  my ( $pid, $host ) = $self->_decode_host_key($locked_by);

  # Different host - nothing we can do
  return 1 unless $host eq hostname;

  # This host so check whether the PID is a valid process.
  return unless $self->_process_valid($pid);

  return 1;
}

sub acquire {
  my $self = shift;

  my $lock_name = $self->key;
  my $host_key  = $self->host_key;
  my $table     = $self->table;

  return $self->_with_lock(
    sub {
      $self->_prune_old_sessions;

      my $locked_by = $self->_get_owner($lock_name);
      return if $self->_valid_lock($locked_by);

      my @col = qw( when name locked_by );
      my @bind = ( $lock_name, $host_key );

      if ( $self->_has_session ) {
        push @col,  "session";
        push @bind, $self->session;
      }

      $self->db->do(
        [ "REPLACE INTO {$table} (",
          join( ", ", map "{$_}", @col ),
          ") VALUES (",
          join( ", ", "NOW()", map "?", @bind ),
          ")"
        ],
        {},
        @bind
      );

      return $host_key;
    }
  );
}

sub wait_for {
  my ( $self, $timeout ) = @_;
  my $lock = $self->acquire;
  return $lock if defined $lock;

  my $deadline = time + $timeout;
  my $sleep    = 0.01;

  while ( time < $deadline ) {
    sleep $sleep;
    my $lock = $self->acquire;
    return $lock if defined $lock;
    $sleep *= 1.3;
  }

  return;
}

sub release_named {
  my ( $self, $host_key ) = @_;

  my $lock_name = $self->key;
  my $table     = $self->table;

  $self->_with_lock(
    sub {
      my $locked_by = $self->_get_owner($lock_name);

      die "Attempt to release a lock we don't hold",
       " (expected $host_key, got $locked_by)"
       unless defined $locked_by && $locked_by eq $host_key;

      $self->db->do(
        [ "UPDATE {$table}",
          "   SET {locked_by} = NULL, {when} = NOW()",
          " WHERE {name} = ?",
          "   AND {locked_by} = ?"
        ],
        {},
        $lock_name,
        $host_key
      );
    }
  );

  return;
}

sub release {
  my $self = shift;
  return $self->release_named( $self->host_key );
}

sub locked {
  my ( $self, $timeout, $cb ) = @_;

  my $token = $self->wait_for($timeout);
  return unless defined $token;

  try { $cb->() }
  catch { confess $_ }
  finally { $self->release };

  return 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
