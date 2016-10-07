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
use Fenchurch::Syncotron::Client;
use Fenchurch::Syncotron::MessageQueue;
use Fenchurch::Syncotron::Server;

preflight;

my @tables = qw(
 test_contributors
 test_edit
 test_programmes_v2
 test_queue
 test_related
 test_state
 test_versions
);

empty @tables;

my $programmes = test_data("stash.json");

my $db_local  = Fenchurch::Core::DB->new( dbh => database("local") );
my $db_remote = Fenchurch::Core::DB->new( dbh => database("remote") );

my $client = make_client($db_local);
my $server = make_server($db_remote);

iterate( $client, $server, 5 );

ok 1, "Boo!";

done_testing;

sub pump_queue {
  my ( $mq_in, $mq_out ) = @_;
  $mq_out->send( $mq_in->take );
}

sub pump {
  my ( $client, $server ) = @_;
  pump_queue( $client->mq_out, $server->mq_in );
  pump_queue( $server->mq_out, $client->mq_in );
}

sub iterate {
  my ( $client, $server, $count ) = @_;

  $count //= 1;

  for ( 1 .. $count ) {
    $client->next;
    pump( $client, $server );
    $server->next;
    pump( $client, $server );
  }
}

sub make_versions {
  my $db  = shift;
  my $adv = Fenchurch::Adhocument::Versions->new(
    schema        => schema(),
    db            => $db,
    version_table => 'test_versions'
  );
}

sub make_server {
  my $db = shift;
  return Fenchurch::Syncotron::Server->new(
    db        => $db,
    node_name => 'other_node',
    mq_in     => make_mq( $db, 'server', 'test_node', 'other_node' ),
    mq_out    => make_mq( $db, 'server', 'other_node', 'test_node' ),
    versions  => make_versions($db),
  );
}

sub make_client {
  my $db = shift;
  return Fenchurch::Syncotron::Client->new(
    db        => $db,
    node_name => 'test_node',
    table     => 'test_state',
    mq_in     => make_mq( $db, 'client', 'other_node', 'test_node' ),
    mq_out    => make_mq( $db, 'client', 'test_node', 'other_node' ),
    versions  => make_versions($db),
  );
}

sub make_mq {
  my ( $db, $role, $from, $to ) = @_;

  return Fenchurch::Syncotron::MessageQueue->new(
    role  => $role,
    from  => $from,
    to    => $to,
    db    => $db,
    table => 'test_queue'
  );
}

sub schema {
  return Fenchurch::Adhocument::Schema->new(
    schema => test_data("schema.json") );
}

