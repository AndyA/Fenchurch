#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Adhocument::Schema;

preflight;

my $schema = Fenchurch::Adhocument::Schema->new(
  schema => test_data("schema.json") );

eq_or_diff $schema->spec_for("programme"),
 {children => {
    contributors => { fkey => '_parent', kind => 'contributor' },
    related      => { fkey => '_parent', kind => 'related' }
  },
  options => { ignore_extra_columns => 0 },
  pkey    => '_uuid',
  plural  => 'programmes',
  table   => 'test_programmes_v2'
 },
 "spec_for";

is $schema->pkey_for("programme"), "_uuid", "pkey_for";
is $schema->table_for("programme"), "test_programmes_v2", "table_for";
eq_or_diff [$schema->tables_for("programme")],
 ['test_contributors', 'test_programmes_v2', 'test_related'],
 "tables_for";

done_testing;

# vim:ts=2:sw=2:et:ft=perl

