#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;
use Fenchurch::Syncotron::Client;
use Fenchurch::Syncotron::MessageQueue;
use Fenchurch::Syncotron::Server;

preflight;

empty 'test_state', 'test_queue';

my $db = Fenchurch::Core::DB->new( dbh => database );

{
  my $eng = make_client($db);
  $eng->state->progress(100);
  $eng->state->state("leaves");
  is $eng->state->progress, 0, "Change state zeros progress";
  $eng->state->progress(50);
  $eng->save_state;
}

{
  my $eng = make_client($db);
  is $eng->state->state,    "leaves", "State serialised";
  is $eng->state->progress, 50,       "Progress serialised";
}

done_testing;

sub make_client {
  my $db = shift;
  return Fenchurch::Syncotron::Client->new(
    node_name => 'test_node',
    mq_in     => make_mq( $db, 'client', 'other_node', 'test_node' ),
    mq_out    => make_mq( $db, 'client', 'test_node', 'other_node' ),
    table     => 'test_state',
    db        => $db
  );
}

sub make_mq {
  my ( $db, $role, $from, $to ) = @_;

  return Fenchurch::Syncotron::MessageQueue->new(
    role  => $role,
    from  => $from,
    to    => $to,
    db    => $db,
    table => 'test_queue'
  );
}

