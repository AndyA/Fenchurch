#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument::Versions;
use Fenchurch::Core::DB;
use Fenchurch::Syncotron::Engine;

preflight;

{
  my ( $vl, $el ) = make_test_db( database("local") );
  my ( $vr, $er ) = make_test_db( database("remote") );

  my @items = make_test_data(2);

  is $el->serial, 0, "Serial initially zero";
  eq_or_diff [$el->leaves( 0, 100 )], [], "No leaves yet";
  eq_or_diff [$el->sample( 0, 100 )], [], "No non-leaves yet";
  eq_or_diff [$el->since( 0, 100 )], [], "No changes yet";

  $vl->save( item => @items );

  my $sno = $el->serial;
  is $sno, 2, "Serial counts two changes";

  $items[0]{name} = "Item 1 (edited)";
  push @{ $items[0]{tags} }, { index => "2", name => "New T\x{1f601}g 1" };

  $vl->save( item => @items );

  is $el->serial, 3, "Serial counts three changes";

  # Should now have two leaves and one non-leaf node
  my @since = $el->since( 0, 100 );
  my @leaves = $el->leaves( 0, 100 );
  my @sample = $el->sample( 0, 100 );

  is scalar(@since),  3, "Three change nodes";
  is scalar(@leaves), 2, "Two leaf nodes";
  is scalar(@sample), 1, "One non-leaf node";

  eq_or_diff [sort @leaves, @sample], [sort @since],
   "Leaves + sample = since";

  ok valid_uuid(@since),  "Since: valid UUIDs";
  ok valid_uuid(@leaves), "Leaves: valid UUIDs";
  ok valid_uuid(@sample), "Sample: valid UUIDs";

  eq_or_diff [$el->dont_have(@since)], [], "Local has all versions";
  eq_or_diff [$er->dont_have(@since)], [@since], "Remote has no versions";

  eq_or_diff [$er->want( 0, 100 )], [], "Remote wants nothing";
  $er->known(@leaves);
  eq_or_diff [sort $er->want( 0, 100 )], [sort @leaves],
   "Remote wants leaves";

  my $leaves = $vl->load_versions(@leaves);
  $er->add_versions(@$leaves);

  eq_or_diff [$er->dont_have(@since)], [@sample],
   "Remote needs non-leaf nodes";

  my @want = $er->want( 0, 100 );
  eq_or_diff [@want], [@sample], "Remote wants non-leaf nodes";

  my $wanted = $vl->load_versions(@want);
  $er->add_versions(@$wanted);

  eq_or_diff [$er->dont_have(@since)], [], "Remote has all versions";
  eq_or_diff [$er->want( 0, 100 )], [], "Remote wants no versions";

  check_data( $vl, $vr, @items );

  # More data, edits
  push @items, make_test_data(2);
  $items[1]{name} = "Bonky Pies";
  $vl->save( item => @items );

  sync_complete( $vl, $el, $vr, $er );
  check_data( $vl, $vr, @items );

  {
    my @del = splice @items, 1, 2;
    $vl->delete( item => map { $_->{_uuid} } @del );
  }

  sync_complete( $vl, $el, $vr, $er );
  check_data( $vl, $vr, @items );

  $items[0]{name} .= " (awooga!)";
  $vl->save( item => @items );

  sync_complete( $vl, $el, $vr, $er );
  check_data( $vl, $vr, @items );

  # Lots of edits
  for ( 1 .. 10 ) {
    push @items, make_test_data(5);
    $vl->save( item => @items );

    my @rot = splice @items, 0, 2;
    push @items, reverse @rot;

    $items[0]{name} .= " (awooga!)";
    $vl->save( item => @items );

    my @del = splice @items, 1, 2;
    $vl->delete( item => map { $_->{_uuid} } @del );
  }

  sync_complete( $vl, $el, $vr, $er );
  check_data( $vl, $vr, @items );

  eq_or_diff [walk_versions( $vr->dbh )],
   [walk_versions( $vl->dbh )], "Version tree matches";

}

done_testing;

sub walk_versions {
  my $db   = shift;
  my $vers = $db->selectall_arrayref(
    join( " ",
      "SELECT `uuid`, `parent`, `kind`, `object`",
      "  FROM `test_versions`",
      " ORDER BY `uuid`" ),
    { Slice => {} }
  );
  my %by_uuid = ();
  for my $ver (@$vers) {
    $by_uuid{ $ver->{uuid} } = $ver;
  }
  my @root = ();
  for my $ver (@$vers) {
    if ( defined $ver->{parent} ) {
      my $parent = $by_uuid{ $ver->{parent} };
      push @{ $parent->{children} }, $ver;
    }
    else {
      push @root, $ver;
    }
  }
  return @root;
}

sub check_data {
  my ( $vl, $vr, @items ) = @_;

  my $name = another("Sync check");

  my @ids = map { $_->{_uuid} } @items;
  my $local  = $vl->load( item => @ids );
  my $remote = $vr->load( item => @ids );

  eq_or_diff $local,  [@items], "$name: Local data matches";
  eq_or_diff $remote, [@items], "$name: Remote data matches";
}

sub sync_complete {
  my ( $vl, $el, $vr, $er ) = @_;

  my $name = another("Sync");

  my @leaves = $er->dont_have( $el->leaves( 0, 1_000_000 ) );
  my $leaves = $vl->load_versions(@leaves);
  $er->add_versions(@$leaves);

  my %seen = ();

  while () {
    my @want = $er->want( 0, 4 );
    last unless @want;
    my @dup = grep { $seen{$_}++ } @want;
    eq_or_diff [@dup], [], "$name: no duplicates";
    my $want = $vl->load_versions(@want);
    $er->add_versions(@$want);
  }
}

sub another {
  my $name = shift;
  state %seq;
  my $idx = ++$seq{$name};
  return join " ", $name, $idx;
}

sub make_test_data {
  my $count = shift // 1;

  my @data = ();
  for ( 1 .. $count ) {
    push @data,
     {_uuid => make_uuid(),
      name  => another("Item"),
      tags  => [
        { index => "0",
          name  => another("T\x{1f601}g")
        },
        { index => "1",
          name  => another("T\x{1f601}g") }
      ],
      nodes => [
        { _uuid => make_uuid(),
          name  => another("Node") }
      ],
     };
  }
  return @data;
}

sub make_test_db {
  my $dbh = shift;

  $dbh->do("TRUNCATE `$_`") for qw(
   test_versions test_pending test_known test_item test_tag test_tree
  );

  my $db = Fenchurch::Core::DB->new(
    dbh    => $dbh,
    tables => {
      versions => 'test_versions',
      pending  => 'test_pending',
      known    => 'test_known',
    }
  );

  my $schema = Fenchurch::Adhocument::Schema->new(
    db     => $db,
    schema => {
      item => { table => 'test_item', },
      tag  => {
        table    => 'test_tag',
        child_of => { item => '_parent' },
        plural   => 'tags',
        order    => '+index'
      },
      node => {
        table    => 'test_tree',
        child_of => { item => '_parent' },
        plural   => 'nodes'
      } }
  );

  my $versions = Fenchurch::Adhocument::Versions->new(
    db     => $db,
    schema => $schema
  );

  my $engine = Fenchurch::Syncotron::Engine->new( versions => $versions );

  return $versions, $engine;
}

# vim:ts=2:sw=2:et:ft=perl

