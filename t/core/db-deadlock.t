#!perl

use strict;
use warnings;
use Test::More;

use lib qw( t/lib );

use JSON;
use Test::Differences;
use Test::More;
use POSIX qw( exit );
use TestSupport;

use Fenchurch::Core::DB;

preflight;

pipe my ( $rdok, $wrok );
$wrok->autoflush(1);

my $pid = fork;
die "Can't fork: $!"
 unless defined $pid;

# Parent and child
my $db = Fenchurch::Core::DB->new( dbh => database );

$db->dbh->{PrintError} = 0;

# See
#  https://www.xaprb.com/blog/2006/08/08/how-to-deliberately-cause-a-deadlock-in-mysql/

if ($pid) {
  # Parent
  $db->do("DROP TABLE IF EXISTS temp_deadlock_maker");
  $db->do(
    "CREATE TABLE temp_deadlock_maker(a INT PRIMARY KEY) ENGINE=INNODB");
  $db->do("INSERT INTO temp_deadlock_maker(a) VALUES (0), (1)");
  print $wrok "OK\n";
}
else {
  <$rdok>;
}

$db->do("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE");
my $try  = 0;
my $done = 0;
$db->transaction(
  sub {
    if ( $try++ ) {
      $db->do("SELECT 1");
      $done++;
    }
    else {
      if ($pid) {
        # parent
        $db->do("SELECT * FROM temp_deadlock_maker WHERE a = 0");
        sleep 2;
        $db->do("UPDATE temp_deadlock_maker SET a = 2 WHERE a <> 0");
      }
      else {
        # child
        $db->do("SELECT * FROM temp_deadlock_maker WHERE a = 1");
        sleep 1;
        $db->do("UPDATE temp_deadlock_maker SET a = 3 WHERE a <> 1");
      }
    }
  }
);

if ($pid) {
  waitpid $pid, 0;

  is $done, 1, "Deadlock: retry";

  done_testing;
}
else {
  POSIX::exit(0);
}

# vim:ts=2:sw=2:et:ft=perl

