#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use MooseX::Test::Role;
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;
use Fenchurch::Syncotron::Role::Stateful;
use Fenchurch::Syncotron::Fault;
use Fenchurch::Syncotron::State;

preflight;

empty 'test_state';

{
  my $st = make_state();

  is $st->state->state, "init", "New state: init";

  $st->state->state("enumerate");
  $st->state->progress(30);
  $st->save_state;
  $st->state->state("recent");

  is $st->state->state, "recent", "State set to recent";
}

{
  my $st = make_state();

  is $st->state->state, "enumerate", "Thawed state: enumerate";

  is $st->state->progress, 30, "Progress persisted";

  $st->state->fault(
    Fenchurch::Syncotron::Fault->new(
      location => 'local',
      error    => 'Just testing'
    )
  );

  $st->save_state;
}

{
  my $st = make_state();

  is $st->state->state, "fault", "Thawed state: fault";

  $st->clear_state;

  is $st->state->state, "init", "Cleared state: init";
}

{
  my $st = make_state();

  is $st->state->state, "init", "Cleared state: still init";
}

done_testing;

sub make_state {
  my $db = Fenchurch::Core::DB->new(
    dbh    => database("local"),
    tables => { state => 'test_state' }
  );

  my $st = consumer_of(
    'Fenchurch::Syncotron::Role::Stateful',
    db               => sub { $db },
    dbh              => sub { $db->dbh },
    node_name        => "here",
    remote_node_name => "there"
  );

  return $st;
}

# vim:ts=2:sw=2:et:ft=perl

