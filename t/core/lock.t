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

for ( 1 .. 2 ) {
  my $token1 = $lock1->acquire;
  ok !!$token1, "Got lock 1";
  my $token2 = $lock2->acquire;
  ok !!$token2, "Got lock 2";
  my $token3 = $lock1->acquire;
  ok !$token3, "Can't get lock 1 again";
  $lock2->release;
  $lock1->release;
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

