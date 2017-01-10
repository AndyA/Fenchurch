#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;
use TestSupport;

use Fenchurch::Core::DB;
use Fenchurch::Core::Lock;

preflight;

my $db = Fenchurch::Core::DB->new(
  dbh     => database,
  aliases => [lock => 'test_lock']
);

my $lock1 = Fenchurch::Core::Lock->new( db => $db, key => "test 1" );
my $lock2 = Fenchurch::Core::Lock->new( db => $db, key => "test 2" );

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

done_testing;

# vim:ts=2:sw=2:et:ft=perl

