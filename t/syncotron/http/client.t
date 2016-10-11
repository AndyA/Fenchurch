#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;
use TestUA;

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument::Versions;
use Fenchurch::Core::DB;
use Fenchurch::Syncotron::HTTP::Client;
use Fenchurch::Syncotron::HTTP::Server;

preflight;

my @tables = qw(
 test_state
 test_pending
 test_versions
 test_item
 test_tag
 test_tree
);

empty @tables;

my $local_versions  = make_versions( database("local"),  "local" );
my $remote_versions = make_versions( database("remote"), "remote" );

my $ua = TestUA->new(
  handler => sub {
    my $body   = shift;
    my $server = Fenchurch::Syncotron::HTTP::Server->new(
      versions  => $remote_versions,
      node_name => "remote"
    );
    return $server->handle($body);
  }
);

my $client = Fenchurch::Syncotron::HTTP::Client->new(
  uri       => 'http://example.com/sync',
  _ua       => $ua,
  versions  => $local_versions,
  node_name => "local",
);

$client->next for 1 .. 4;

ok 1, "OK!";

done_testing;

sub make_versions {
  my ( $dbh, $node ) = @_;

  my $db = Fenchurch::Core::DB->new(
    dbh    => $dbh,
    tables => {
      versions => 'test_versions',
      pending  => 'test_pending',
      state    => 'test_state',
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
    db        => $db,
    schema    => $schema,
    node_name => $node
  );

  return $versions;
}

# vim:ts=2:sw=2:et:ft=perl

