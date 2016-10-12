package Fenchurch::Syncotron::MessageQueue::Persistent;

our $VERSION = "1.00";

use v5.10;

use Moose;

has ['role', 'from', 'to'] => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

with 'Fenchurch::Core::Role::DB', 'Fenchurch::Core::Role::JSON';

=head1 NAME

Fenchurch::Syncotron::MessageQueue::Persistent - A persistent message queue

=cut

=head2 C<< send >>

Send messages.

=cut

sub send {
  my ( $self, @msgs ) = @_;

  return $self unless @msgs;

  my $role = $self->role;
  my $from = $self->from;
  my $to   = $self->to;

  $self->dbh->do(
    $self->db->quote_sql(
      "INSERT INTO {:queue} ({role}, {from}, {to}, {when}, {message}) VALUES ",
      join( ", ", map "(?, ?, ?, NOW(), ?)", @msgs )
    ),
    {},
    map { ( $role, $from, $to, $self->_json_encode($_) ) } @msgs
  );

  return $self;
}

=head2 C<< available >>

Find out how many messages are available on the queue.

=cut

sub available {
  my $self = shift;

  my ($avail) = $self->dbh->selectrow_array(
    $self->db->quote_sql(
      "SELECT COUNT(*) FROM {:queue}",
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

  return $self->dbh->selectall_arrayref(
    $self->db->quote_sql(
      "SELECT {id}, {message} FROM {:queue}",
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
  return map { $self->_json_decode( $_->{message} ) } @$msg;
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

  if (@id) {
    $self->dbh->do(
      $self->db->quote_sql(
        "DELETE FROM {:queue} WHERE {id} IN (",
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

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
