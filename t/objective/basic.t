#!perl

use v5.10;

use strict;
use warnings;
use Test::More;

use lib qw( t/lib );

use Storable qw( dclone );
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument;
use Fenchurch::Core::DB;
use Fenchurch::Objective;

preflight;

my @tables = qw(
 test_contributors
 test_programmes_v2
 test_related
);

my $programmes = test_data("stash.json");

{
  empty(@tables);
  my $ad = Fenchurch::Adhocument->new(
    db     => Fenchurch::Core::DB->new( dbh              => database ),
    schema => Fenchurch::Adhocument::Schema->new( schema => schema() )
  );
  my $obj = Fenchurch::Objective->new( engine => $ad );
  $obj->save( programme => @$programmes );
  my $progs = $obj->load( programme => map { $_->{_uuid} } @$programmes );
  isa_ok $progs->[0], "Fenchurch::Objective::Instance";
  is $progs->[0]->title, $programmes->[0]{title},
   "title attribute populated";

  for my $prog (@$progs) {
    $prog->title( $prog->title . " (modified)" );
  }

  my $want = dclone $programmes;
  $_->{title} .= " (modified)" for @$want;

  empty(@tables);

  $obj->save( programme => @$progs );

  my $got = $ad->load( programme => map { $_->{_uuid} } @$programmes );
  eq_or_diff $got, $want, "modify + save works";
}

done_testing;

sub schema {
  return {
    programme => {
      pkey   => "_uuid",
      plural => "programmes",
      table  => "test_programmes_v2"
    },
    contributor => {
      child_of => { programme => "_parent" },
      order    => "+index",
      plural   => "contributors",
      table    => "test_contributors"
    },
    related => {
      child_of => { programme => "_parent" },
      order    => "+index",
      pkey     => "_uuid",
      table    => "test_related"
    } };
}

# vim:ts=2:sw=2:et:ft=perl

