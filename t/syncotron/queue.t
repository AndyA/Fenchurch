#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Syncotron::MessageQueue;

my $mq = Fenchurch::Syncotron::MessageQueue->new;

is $mq->available, 0, "Queue initially empty";

$mq->send( { index => 1, name => "First" },
  { index => 2, name => "Second" } );

$mq->send( { index => 4, name => "Third" } );

is $mq->available, 3, "Three message on queue";

eq_or_diff [$mq->peek(1)], [{ index => 1, name => "First" }],
 "Peek got first message";

eq_or_diff [$mq->peek(2)],
 [{ index => 1, name => "First" }, { index => 2, name => "Second" }],
 "Peek got first two messages";

eq_or_diff [$mq->peek],
 [{ index => 1, name => "First" },
  { index => 2, name => "Second" },
  { index => 4, name => "Third" }
 ],
 "Peek got all three messages";

is $mq->available, 3, "Three messages still on queue";

eq_or_diff [$mq->take(1)], [{ index => 1, name => "First" }],
 "Take got first message";

is $mq->available, 2, "Two messages still on queue";

eq_or_diff [$mq->take],
 [{ index => 2, name => "Second" }, { index => 4, name => "Third" }],
 "Take got remaining two messages";

is $mq->available, 0, "Queue empty";

{
  my @got  = ();
  my $done = 0;
  $mq->with_messages( sub { $done++; push @got, @_ } );
  is $done, 1, "One callback";
  eq_or_diff [@got], [], "No messages";
}

$mq->send( { index => 3, name => "First" },
  { index => 5, name => "Second" } );

{
  my @got  = ();
  my $done = 0;
  $mq->with_messages( sub { $done++; push @got, @_ } );
  is $done, 1, "One callback";
  eq_or_diff [@got],
   [{ index => 3, name => "First" }, { index => 5, name => "Second" }],
   "Two messages";
  is $mq->available, 0, "Queue empty";
}

{
  $mq->send( { index => 6, name => "Third" },
    { index => 7, name => "Fourth" } );

  eval {
    $mq->with_messages( sub { die } );
  };

  ok !!$@, "Error thrown";
  eq_or_diff [$mq->take],
   [{ index => 6, name => "Third" }, { index => 7, name => "Fourth" }],
   "Messages left on queue";
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

