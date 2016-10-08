package Fenchurch::Syncotron::Role::Stateful;

our $VERSION = "0.01";

use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::State;

requires 'node_name', 'remote_node_name';

has state => (
  is      => 'ro',
  isa     => duck_type( ['state'] ),
  lazy    => 1,
  builder => '_b_state',
);

=head1 NAME

Fenchurch::Syncotron::Role::Stateful - Persistent state

=cut

sub _load_state {
  my $self = shift;

  my ($state) = $self->dbh->selectrow_array(
    $self->db->quote_sql(
      "SELECT {state} FROM {:state}",
      " WHERE {local_node} = ? AND {remote_node} = ?"
    ),
    {},
    $self->node_name,
    $self->remote_node_name
  );

  return unless $state;
  return Fenchurch::Syncotron::State->thaw($state);
}

sub save_state {
  my $self = shift;

  $self->dbh->do(
    $self->db->quote_sql(
      "REPLACE INTO {:state}",
      "   ({local_node}, {remote_node}, {updated}, {state})",
      " VALUES (?, ?, NOW(), ?)"
    ),
    {},
    $self->node_name,
    $self->state->freeze
  );
}

sub _b_state {
  my $self = shift;
  return $self->_load_state // Fenchurch::Syncotron::State->new;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl