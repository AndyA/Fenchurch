#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Syncotron::Client;

preflight;

empty 'test_state';

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
    node_name   => 'test_node',
    state_table => 'test_state',
    db          => $db
  );
}
