#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use FakeDB;
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;

preflight;

my $fake = FakeDB->new;
my $db = Fenchurch::Core::DB->new( dbh => $fake );

{
  is $db->in_lock, 0, "not in a lock";
  my $done_it = 0;

  $db->lock(
    ["foo", "bar"],
    sub {
      is $db->in_lock, 1, "in a lock";
      $db->lock(
        "baz",
        sub {
          is $db->in_lock, 1, "still in a lock";
          $done_it++;
        }
      );
    }
  );

  is $db->in_lock, 0, "not in a lock again";

  is $done_it, 1, "executed code once";

  eq_or_diff [$fake->history],
   [["LOCK TABLES `foo` WRITE, `bar` WRITE"], ["UNLOCK TABLES"]],
   "normal lock";

  eq_or_diff [$fake->history], [], "history drained";
}

{
  eval {
    $db->lock(
      ["foo", "bar"],
      sub {
        $db->lock( "baz", sub { die "Oh no!" } );
      }
    );
  };

  my $err = $@;
  like $err, qr{^Oh no!}, "error caught";

  eq_or_diff [$fake->history],
   [["LOCK TABLES `foo` WRITE, `bar` WRITE"], ["UNLOCK TABLES"]],
   "aborted lock";

  is $db->in_lock, 0, "lock removed";
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

