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

my %common = (
  aliases => [
    queue    => 'test_queue',
    versions => 'test_versions',
    state    => 'test_state',
    pending  => 'test_pending',
    known    => 'test_known',
    lock     => 'test_lock',
  ]
);

my $db_local
 = Fenchurch::Core::DB->new( dbh => database("local"), %common );
my $db_remote
 = Fenchurch::Core::DB->new( dbh => database("remote"), %common );

my $client = make_client($db_local);
my $server = make_server($db_remote);

$server->versions->save( programme => @$programmes );

for ( 1 .. 10 ) {
  iterate( $client, $server, 1 );

  my $rot = shift @$programmes;
  $server->versions->delete( programme => $rot->{_uuid} );
  $rot->{_uuid} = make_uuid();
  push @$programmes, $rot;
  $server->versions->save( programme => $rot );

  $programmes->[0]{title} .= " (Awooga!)";
  $server->versions->save( programme => $programmes->[0] );
}

iterate( $client, $server, 10 );

check_data( $client->versions, $server->versions, @$programmes );

eq_or_diff [walk_versions( $db_remote->dbh )],
 [walk_versions( $db_local->dbh )], "Version tree matches";

done_testing;

sub check_data {
  my ( $vl, $vr, @items ) = @_;

  my $name = another("Sync check");

  my @ids = map { $_->{_uuid} } @items;
  my $local  = $vl->load( programme => @ids );
  my $remote = $vr->load( programme => @ids );

  eq_or_diff $local,  [@items], "$name: Local data matches";
  eq_or_diff $remote, [@items], "$name: Remote data matches";
}

sub another {
  my $name = shift;
  state %seq;
  my $idx = ++$seq{$name};
  return join " ", $name, $idx;
}

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
    schema => schema(),
    db     => $db,
  );
}

sub make_server {
  my $db = shift;
  return Fenchurch::Syncotron::Server->new(
    db        => $db,
    node_name => 'other_node',
    versions  => make_versions($db),
    page_size => 5,
  );
}

sub make_client {
  my $db = shift;
  return Fenchurch::Syncotron::Client->new(
    db               => $db,
    node_name        => 'test_node',
    remote_node_name => 'other_node',
    versions         => make_versions($db),
    page_size        => 5,
  );
}

sub schema {
  return Fenchurch::Adhocument::Schema->new(
    schema => test_data("schema.json") );
}

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
      my $parent = $by_uuid{ $ver->{parent} }
       || die "Missing parent $ver->{parent}";
      push @{ $parent->{children} }, $ver;
    }
    else {
      push @root, $ver;
    }
  }
  return @root;
}

sub show_versions {
  my $indent = shift // 0;
  my $pad = "  " x $indent;
  for my $ver (@_) {
    diag $pad, join " ", @{$ver}{ 'kind', 'uuid', 'object', 'serial' };
    show_versions( $indent + 1, @{ $ver->{children} // [] } );
  }
}

