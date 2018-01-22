#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;
use Sanity;

use Fenchurch::Adhocument::Sanity::Tree;
use Fenchurch::Core::DB;

preflight;

my $db = Fenchurch::Core::DB->new(
  dbh     => database,
  aliases => [versions => 'test_versions']
);

{
  load_test_data( database, 'test_versions', 'tree', 'good.json' );
  my $ts = sanity_tree($db);
  $ts->check;
  my @log = $ts->report->get_log;
  eq_or_diff [@log], [], "Good tree: empty error log";
  test_sanity($db);
}

{
  load_test_data( database, 'test_versions', 'tree',
    'bad-structure.json' );
  my $ts = sanity_tree($db);
  $ts->check;
  my @log = $ts->report->get_log;
  eq_or_diff [@log],
   ['02c0295d-6009-4ea0-9b5f-3677a78681c1 is not a descendent of '
     . '15d40bf8-9ad9-400d-9884-2cafaa5c9914'
     . '/00dac376-5da5-4ed1-8df7-9efdb039e65c'
     . '/02f1b36c-cf74-4680-9863-5e882f30b2b9'
     . '/03a6418a-e160-4cbd-b9e5-151ce4d0b061',
    '02f1b36c-cf74-4680-9863-5e882f30b2b9 is not a descendent of '
     . '15d40bf8-9ad9-400d-9884-2cafaa5c9914'
     . '/00dac376-5da5-4ed1-8df7-9efdb039e65c'
     . '/013746c2-9886-45a9-86fe-209fe772c6dc'
     . '/02c0295d-6009-4ea0-9b5f-3677a78681c1'
   ],
   "Bad structure: log as expected";
}

done_testing;

sub sanity_tree {
  my $db = shift;
  return Fenchurch::Adhocument::Sanity::Tree->new(
    db    => $db,
    since => 0
  );
}

sub load_test_data {
  my ( $db, $table, @path ) = @_;
  my $stash = test_data(@path);
  empty($table);
  insert( $db, $table, $stash );
}

# vim:ts=2:sw=2:et:ft=perl

