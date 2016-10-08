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
  my ( $versions, $engine, @items ) = make_test_db();

  is $engine->serial, 0, "Serial initially zero";
  eq_or_diff [$engine->leaves( 0, 100 )], [], "No leaves yet";
  eq_or_diff [$engine->sample( 0, 100 )], [], "No non-leaves yet";
  eq_or_diff [$engine->since( 0, 100 )], [], "No changes yet";

  $versions->save( item => @items );

  is $engine->serial, 2, "Serial counts two changes";

  $items[0]{name} = "Item 1 (edited)";
  push @{ $items[0]{tags} }, { index => "2", name => "New Tag 1" };
  push @{ $items[0]{nodes} },
   { _uuid => make_uuid(), name => "New Node 1" };

  $versions->save( item => @items );

  is $engine->serial, 3, "Serial counts three changes";

  # Should now have two leaves and one non-leaf node
  my @since = $engine->since( 0, 100 );
  my @leaves = $engine->leaves( 0, 100 );
  my @sample = $engine->sample( 0, 100 );

  is scalar(@since),  3, "Three change nodes";
  is scalar(@leaves), 2, "Two leaf nodes";
  is scalar(@sample), 1, "One non-leaf node";

  ok valid_uuid(@since),  "Since: valid UUIDs";
  ok valid_uuid(@leaves), "Leaves: valid UUIDs";
  ok valid_uuid(@sample), "Sample: valid UUIDs";
}

done_testing;

sub make_test_db {

  empty qw( test_versions test_item test_tag test_tree );

  my %common = ( tables => { versions => 'test_versions' } );

  my $db_local = Fenchurch::Core::DB->new(
    dbh => database("local"),
    %common
  );

  my $db_remote = Fenchurch::Core::DB->new(
    dbh => database("remote"),
    %common
  );

  my $schema = Fenchurch::Adhocument::Schema->new(
    db     => $db_local,
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
    db     => $db_local,
    schema => $schema
  );

  my $engine = Fenchurch::Syncotron::Engine->new( versions => $versions );

  my @items = (
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

  return $versions, $engine, @items;
}

# vim:ts=2:sw=2:et:ft=perl

