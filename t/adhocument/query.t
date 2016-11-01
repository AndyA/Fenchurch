#!perl

use strict;
use warnings;

use lib qw( t/lib );

use DBI;
use Storable qw( dclone );
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;
use Fenchurch::Adhocument;

preflight;

my @tables = qw(
 test_contributors
 test_edit
 test_programmes_v2
 test_related
 test_versions
);

empty(@tables);

my $programmes = test_data("stash.json");

adhocument()->save( programme => @$programmes );

my $ad = adhocument();

{
  my $docs = $ad->query(
    programme => "SELECT * FROM {test_programmes_v2} WHERE {year} = ?",
    1931
  );

  eq_or_diff $docs, [$programmes->[0]],
   "Query selected the right programme";
}

{
  my $rec = dclone $programmes->[0];
  delete @{$rec}{ 'contributors', 'related' };
  my $docs = $ad->deepen( programme => [$rec] );
  eq_or_diff $docs, [$programmes->[0]],
   "Deepen deepens";
}

done_testing;

sub adhocument {
  return Fenchurch::Adhocument->new(
    schema => schema(),
    db     => Fenchurch::Core::DB->new( dbh => database )
  );
}

sub schema {
  return Fenchurch::Adhocument::Schema->new(
    schema => test_data("schema.json") );
}

# vim:ts=2:sw=2:et:ft=perl
