#!perl

use strict;
use warnings;

use lib qw( t/lib );

use JSON;
use Test::Differences;
use Test::More;
use TestSupport;
use POSIX qw( exit );

use Fenchurch::Core::DB;

preflight;

{
  my $db = Fenchurch::Core::DB->new( get_connection => sub { database } );
  my ($ok) = $db->selectrow_array( "SELECT ? AS {ok}", {}, "OK" );
  is $ok, "OK", "get_connection supplies dbh";
}

for my $i ( 1 .. 100 ) {
  my $db = Fenchurch::Core::DB->new( get_connection => sub { database } );

  {
    my ($ok) = $db->selectrow_array( "SELECT ? AS {ok}", {}, "OK" );
    is $ok, "OK", "get_connection before fork";
  }

  my $pid = fork;
  die "Fork failed" unless defined $pid;

  if ($pid) {
    my ($ok) = $db->selectrow_array( "SELECT ? AS {ok}", {}, "Parent" );
    is $ok, "Parent", "dbh working in parent";
  }
  else {
    my ($ok) = $db->selectrow_array( "SELECT ? AS {ok}", {}, "Child" );
    POSIX::exit( $ok ne "Child" );
  }

  waitpid $pid, 0;
  ok !$?, "dbh working in child";

  {
    my ($ok) = $db->selectrow_array( "SELECT ? AS {ok}", {}, "After" );
    is $ok, "After", "dbh working after child exit ";
  }
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

