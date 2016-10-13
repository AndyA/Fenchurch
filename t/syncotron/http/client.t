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

my @local_data  = make_test_data(3);
my @remote_data = make_test_data(4);

$local_versions->save( item => @local_data );
$remote_versions->save( item => @remote_data );

$client->next for 1 .. 7;

check_data( $local_versions, $remote_versions, @local_data,
  @remote_data );

my $report = $client->stats->report;
while ( my ( $kind, $stats ) = each %$report ) {
  is $stats->{count}, 8, "$kind: 8 http requests seen";
  ok $stats->{average} >= $stats->{min}
   && $stats->{average} <= $stats->{max}, "$kind: average looks sane";
}

done_testing;

sub check_data {
  my ( $vl, $vr, @items ) = @_;

  my $name = another("Sync check");

  my @ids = map { $_->{_uuid} } @items;
  my $local  = $vl->load( item => @ids );
  my $remote = $vr->load( item => @ids );

  eq_or_diff $local,  [@items], "$name: Local data matches";
  eq_or_diff $remote, [@items], "$name: Remote data matches";
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

