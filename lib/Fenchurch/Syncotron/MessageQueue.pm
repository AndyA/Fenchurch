package Fenchurch::Syncotron::MessageQueue;

our $VERSION = "0.01";

use Moose;

with 'Fenchurch::Core::Role::DB';
with 'Fenchurch::Core::Role::JSON';

has ['role', 'from', 'to'] => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has table => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

=head1 NAME

Fenchurch::Syncotron::MessageQueue - A persistent message queue

=cut

=head2 C<< send >>

Send messages.

=cut

sub send {
  my ( $self, @msgs ) = @_;

  my $table = $self->db->quote_name( $self->table );
  my $role  = $self->role;
  my $from  = $self->from;
  my $to    = $self->to;
  my $json  = $self->_json;

  $self->dbh->do(
    $self->db->quote_sql(
      "INSERT INTO $table ({role}, {from}, {to}, {when}, {message}) VALUES ",
      join( ", ", map "(?, ?, ?, NOW(), ?)", @msgs )
    ),
    {},
    map { ( $role, $from, $to, $json->encode($_) ) } @msgs
  );

  return $self;
}

=head2 C<< available >>

Find out how many messages are available on the queue.

=cut

sub available {
  my $self = shift;

  my $table = $self->db->quote_name( $self->table );

  my ($avail) = $self->dbh->selectrow_array(
    $self->db->quote_sql(
      "SELECT COUNT(*) FROM $table",
      " WHERE {role} = ? AND {from} = ? AND {to} = ?"
    ),
    {},
    $self->role,
    $self->from,
    $self->to
  );

  return $avail;
}

sub _peek {
  my ( $self, $count ) = @_;

  my $table = $self->db->quote_name( $self->table );

  return $self->dbh->selectall_arrayref(
    $self->db->quote_sql(
      "SELECT {id}, {message} FROM $table",
      " WHERE {role} = ? AND {from} = ? AND {to} = ?",
      " ORDER BY {id} ASC",
      ( defined $count ? (" LIMIT ?") : () )
    ),
    { Slice => {} },
    $self->role,
    $self->from,
    $self->to,
    grep { defined } $count
  );
}

sub _unpack {
  my ( $self, $msg ) = @_;
  return unless $msg;
  my $json = $self->_json;
  return map { $json->decode( $_->{message} ) } @$msg;
}

=head2 C<< peek >>

Get a copy of messages from the queue without removing them.

=cut

sub peek {
  my $self = shift;
  return $self->_unpack( $self->_peek(@_) );
}

=head2 C<< take >>

Remove messages from the queue.

=cut

sub take {
  my $self = shift;
  my $msg  = $self->_peek(@_);
  return unless $msg;

  my @rc = $self->_unpack($msg);
  my @id = map { $_->{id} } @$msg;

  my $table = $self->db->quote_name( $self->table );

  if (@id) {
    $self->dbh->do(
      $self->db->quote_sql(
        "DELETE FROM $table WHERE {id} IN (",
        join( ", ", map "?", @id ),
        ")"
      ),
      {},
      @id
    );
  }

  return @rc;
}

=head2 C<< with >>

Run a callback for messages on the queue and then remove them. If the
callback errors the messages will be left on the queue.

=cut

sub with_messages {
  my $self = shift;
  my $cb   = pop;

  $self->db->transaction( sub { $cb->( $self->take(@_) ) } );

  return $self;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
