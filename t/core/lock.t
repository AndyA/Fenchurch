#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;
use TestSupport;

use File::Temp;
use POSIX qw( strftime );
use Path::Class;

use Fenchurch::Core::DB;
use Fenchurch::Core::Lock;

preflight;

for my $table ( 'test_lock', 'test_lock_no_session' ) {

  empty $table;

  my $db = Fenchurch::Core::DB->new(
    dbh     => database,
    aliases => [lock => $table]
  );

  my $time = time;

  {
    my $session = strftime '%Y%m%d-%H%M%S', gmtime $time;

    my $dir = File::Temp->newdir;
    my $sf = file $dir, "session";

    $sf->openw->print("$session\n");

    my $lock1 = Fenchurch::Core::Lock->new(
      db           => $db,
      key          => "test 1",
      session_file => "$sf"
    );

    my $lock2 = Fenchurch::Core::Lock->new(
      db           => $db,
      key          => "test 2",
      session_file => "$sf"
    );

    is $lock1->session, $session, "lock1 session";
    is $lock2->session, $session, "lock2 session";

    for ( 1 .. 4 ) {
      {
        my $token = $lock1->acquire;
        ok !!$token, "Got lock 1";
      }

      {
        my $done = $lock1->locked( 0, sub { } );
        ok !$done, "Can't get lock 1 for locked operation";
      }

      {
        my $cb_run = 0;
        my $done = $lock2->locked( 1, sub { $cb_run++ } );
        ok $done, "Got lock 2 for locked operation";
        is $cb_run, 1, "Locked op run once";
      }

      {
        my $token = $lock2->acquire;
        ok !!$token, "Got lock 2";
      }

      {
        my $token = $lock1->acquire;
        ok !$token, "Can't get lock 1 again";
      }

      $lock2->release;
      $lock1->release;
    }

    my $tok = $lock1->acquire;
    ok !!$tok, "Got lock 1 again";
  }

  {
    my $session = strftime '%Y%m%d-%H%M%S', gmtime $time + 1;

    my $dir = File::Temp->newdir;
    my $sf = file $dir, "session";

    $sf->openw->print("$session\n");

    my $lock1 = Fenchurch::Core::Lock->new(
      db           => $db,
      key          => "test 1",
      session_file => "$sf"
    );

    if ( $lock1->_has_session ) {
      my $tok = $lock1->acquire;
      ok !!$tok, "Got lock 1 in new session";
    }

  }
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

