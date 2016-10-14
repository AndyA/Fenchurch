#!perl

use v5.10;

use strict;
use warnings;

use Test::Differences;
use Test::More;

use Fenchurch::Syncotron::Fault;
use Fenchurch::Syncotron::State;

my $st = Fenchurch::Syncotron::State->new;

is $st->state, 'init', "Default state: init";

is $st->progress, 0, "Progress is zero";

$st->advance(17);
is $st->progress, 17, "Progress advanced to 17";

$st->advance(1);
is $st->progress, 18, "Progress advanced to 18";

$st->state('enumerate');

is $st->progress, 0,  "Progress reset to zero";
is $st->hwm,      18, "High water mark";
$st->advance(13);
is $st->progress, 13, "Advanced again";
is $st->hwm,      18, "High water mark persists";

$st->fault(
  Fenchurch::Syncotron::Fault->new(
    location => 'local',
    error    => 'Just testing'
  )
);

is $st->state, 'fault', "Setting fault moves to 'fault' state";

done_testing;
