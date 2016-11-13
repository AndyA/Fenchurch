#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use DBI;
use Storable qw( dclone );
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;
use Fenchurch::Adhocument::Versions;
use Fenchurch::Adhocument;

preflight;

my @profile = (
  { maker  => \&make_ad_schema,
    type   => 'Fenchurch::Adhocument',
    events => { delete => 3, load => 4, save => 2 }
  },
  { maker  => \&make_ver_schema,
    type   => 'Fenchurch::Adhocument::Versions',
    events => { delete => 3, load => 7, save => 2, version => 3 } }
);

for my $prof (@profile) {
  my $type = $prof->{type};

  test_schema(
    $prof,
    'programme',
    'stash.json',
    { contributor => {
        table    => 'test_contributors',
        child_of => { programme => '_parent' },
        order    => '+index',
        plural   => 'contributors'
      },
      related => {
        table    => 'test_related',
        pkey     => '_uuid',
        child_of => { programme => '_parent' },
        order    => '+index'
      },
      programme => { table => 'test_programmes_v2', pkey => '_uuid' },
    }
  );

  test_schema(
    $prof, 'node',
    'tree.json',
    { node => {
        table    => 'test_tree',
        pkey     => '_uuid',
        child_of => { node => '_parent' },
        order    => '+name',
        plural   => 'nodes'
      },
    }
  );
}

done_testing();

sub make_ad_schema {
  my $schema = shift;
  return Fenchurch::Adhocument->new(
    schema => Fenchurch::Adhocument::Schema->new( schema => $schema ),
    db     => Fenchurch::Core::DB->new( dbh              => database )
  );
}

sub make_ver_schema {
  my $schema = shift;
  return Fenchurch::Adhocument::Versions->new(
    schema => Fenchurch::Adhocument::Schema->new( schema => $schema ),
    db     => Fenchurch::Core::DB->new(
      dbh     => database,
      aliases => [versions => 'test_versions']
    ),
  );
}

sub catch_events {
  my ( $ad, @ev ) = @_;
  my $stash = {};
  for my $ev (@ev) {
    $ad->on( $ev, sub { $stash->{$ev}++ } );
  }
  return $stash;
}

sub test_schema {
  my ( $prof, $kind, $datafile, $schema ) = @_;

  my $type = $prof->{type};

  my $o_schema = dclone $schema;

  for my $tbl ( 'test_versions', map { $_->{table} } values %$schema ) {
    database->do("TRUNCATE `$tbl`");
  }

  my $stash   = test_data($datafile);
  my $o_stash = dclone $stash;
  my @ids     = map { $_->{_uuid} } @$stash;

  my $ad = $prof->{maker}($schema);
  my $events = catch_events( $ad, 'load', 'save', 'delete', 'version' );

  for my $pass ( 1 .. 2 ) {
    $ad->save( $kind => @$stash );
    eq_or_diff $stash, $o_stash, "$type, $kind: stash unchanged";
    my $docs = $ad->load( $kind => @ids );
    eq_or_diff $docs, $stash, "$type, $kind: save, load, pass $pass";
    eq_or_diff object_hash($docs), object_hash($stash),
     "$type, $kind: digest matches, pass $pass";
  }

  # Test that missing documents leave holes in the results array
  {
    my $want = [undef, $stash->[0], undef, $stash->[1], undef];
    my @mids = (
      '9531e3af-fc61-49eb-b047-bf32b834c94e', $ids[0],
      '221fe567-d4db-42e8-b354-b00baba07823', $ids[1],
      '9b3f7cc3-786b-4f97-be30-b96a2ac32341'
    );
    my $docs = $ad->load( $kind => @mids );
    eq_or_diff $docs, $want,
     "$type, $kind: load with missing ids leaves holes";
  }

  $ad->delete( $kind => @ids );

  # Test that nothing bad happens if _none_ of the documents are found.
  {
    my $want = [map { undef } @ids];
    my $docs = $ad->load( $kind => @ids );
    eq_or_diff $docs, $want, "$type, $kind: all missing -> all undef";
  }

  for my $info ( values %$schema ) {
    my ($count)
     = database->selectrow_array("SELECT COUNT(*) FROM `$info->{table}`");
    is $count, 0, "$type, $kind: $info->{table} empty";
  }

  eq_or_diff $schema, $o_schema, "$type, $kind: schema unchanged";

  eq_or_diff $events, $prof->{events}, "$type, $kind: events match";

}

# vim:ts=2:sw=2:et:ft=perl

