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
  is $db->in_transaction, 0, "not in a transaction";
  my $done_it = 0;

  $db->transaction(
    sub {
      is $db->in_transaction, 1, "in a transaction";
      $db->transaction(
        sub {
          is $db->in_transaction, 1, "still in a transaction";
          $done_it++;
        }
      );
    }
  );

  is $db->in_transaction, 0, "not in a transaction again";

  is $done_it, 1, "executed code once";

  eq_or_diff [$fake->history], [["START TRANSACTION"], ["COMMIT"]],
   "normal transaction";

  eq_or_diff [$fake->history], [], "history drained";
}

{
  eval {
    $db->transaction(
      sub {
        $db->transaction( sub { die "Oh no!" } );
      }
    );
  };

  my $err = $@;
  like $err, qr{^Oh no!}, "error caught";

  eq_or_diff [$fake->history], [["START TRANSACTION"], ["ROLLBACK"]],
   "aborted transaction";

  is $db->in_transaction, 0, "transaction lock removed";
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

