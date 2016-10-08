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

  my @items = make_test_data();

  is $el->serial, 0, "Serial initially zero";
  eq_or_diff [$el->leaves( 0, 100 )], [], "No leaves yet";
  eq_or_diff [$el->sample( 0, 100 )], [], "No non-leaves yet";
  eq_or_diff [$el->since( 0, 100 )], [], "No changes yet";

  $vl->save( item => @items );

  is $el->serial, 2, "Serial counts two changes";

  $items[0]{name} = "Item 1 (edited)";
  push @{ $items[0]{tags} }, { index => "2", name => "New Tag 1" };
  push @{ $items[0]{nodes} },
   { _uuid => make_uuid(), name => "New Node 1" };

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

  my $leaves = $vl->load_versions(@leaves);
  $er->add_versions(@$leaves);

  eq_or_diff [$er->dont_have(@since)], [@sample],
   "Remote needs non-leaf nodes";

  my @want = $er->want( 0, 100 );
  eq_or_diff [@want], [@sample], "Remote wants non-leaf nodes";

  my $wanted = $vl->load_versions(@want);
  #  use JSON ();
  #  diag +JSON->new->pretty->canonical->encode($wanted);
  $er->add_versions(@$wanted);

  eq_or_diff [$er->dont_have(@since)], [], "Remote has all versions";
  eq_or_diff [$er->want( 0, 100 )], [], "Remote wants no versions";

  my @ids = map { $_->{_uuid} } @items;
  is scalar(@ids), 2, "Got three document IDs";

  my $local  = $vl->load( item => @ids );
  my $remote = $vr->load( item => @ids );
  eq_or_diff $local, $remote, "Remote data matches local";
}

done_testing;

sub make_test_data {
  return (
    { _uuid => make_uuid(),
      name  => "Item 1",
      tags  => [
        { index => "0",
          name  => "Tag 1"
        },
        { index => "1",
          name  => "Tag 2"
        }
      ],
      nodes => [
        { _uuid => make_uuid(),
          name  => "Node 1"
        }
      ],
    },
    { _uuid => make_uuid(),
      name  => "Item 2",
      tags  => [
        { index => "0",
          name  => "Tag 3"
        },
        { index => "1",
          name  => "Tag 4"
        }
      ],
      nodes => [
        { _uuid => make_uuid(),
          name  => "Node 2"
        }
      ],
    }
  );
}

sub make_test_db {
  my $dbh = shift;

  $dbh->do("TRUNCATE `$_`")
   for qw( test_versions test_pending test_item test_tag test_tree );

  my $db = Fenchurch::Core::DB->new(
    dbh    => $dbh,
    tables => {
      versions => 'test_versions',
      pending  => 'test_pending',
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

