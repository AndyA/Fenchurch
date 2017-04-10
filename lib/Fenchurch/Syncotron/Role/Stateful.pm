package Fenchurch::Syncotron::Role::Stateful;

our $VERSION = "1.00";

use Moose::Role;
use Moose::Util::TypeConstraints;

use Fenchurch::Syncotron::State;

requires 'node_name', 'remote_node_name', 'db', 'log';

has state => (
  is      => 'rw',
  isa     => duck_type( ['state'] ),
  lazy    => 1,
  clearer => 'forget_state',
  builder => '_b_state',
);

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::JSON
);

=head1 NAME

Fenchurch::Syncotron::Role::Stateful - Persistent state

=cut

sub _load_state {
  my $self = shift;

  $self->log->debug( "Loading state for ",
    join ", ", $self->node_name, $self->remote_node_name );

  my ($state) = $self->db->selectrow_array(
    [ "SELECT {state} FROM {:state}",
      " WHERE {local_node} = ? AND {remote_node} = ?"
    ],
    {},
    $self->node_name,
    $self->remote_node_name
  );

  return unless $state;
  $self->log->debug( "Loaded state: ", $state );
  return Fenchurch::Syncotron::State->thaw($state);
}

sub load_all_states {
  my $self = shift;

  my $states = $self->db->selectall_arrayref(
    "SELECT {state}, {remote_node} FROM {:state} WHERE {local_node} = ?",
    { Slice => {} },
    $self->node_name
  );

  my $out = {};
  for my $row (@$states) {
    $out->{ $row->{remote_node} } = $self->json_decode( $row->{state} );
  }
  return $out;
}

sub clear_state {
  my $self = shift;

  $self->forget_state;

  $self->log->debug( "Clearing state for ",
    join ", ", $self->node_name, $self->remote_node_name );

  $self->db->do(
    "DELETE FROM {:state} WHERE {local_node} = ? AND {remote_node} = ?",
    {}, $self->node_name, $self->remote_node_name );
}

sub save_state {
  my $self = shift;

  my $state = $self->state->freeze;

  $self->log->debug(
    "Saving state for ",
    join( ", ", $self->node_name, $self->remote_node_name ),
    ": ", $state
  );

  $self->db->do(
    [ "REPLACE INTO {:state}",
      "   ({local_node}, {remote_node}, {updated}, {state})",
      " VALUES (?, ?, NOW(), ?)"
    ],
    {},
    $self->node_name,
    $self->remote_node_name,
    $state
  );
}

sub _b_state {
  my $self = shift;
  return $self->_load_state // Fenchurch::Syncotron::State->new;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
