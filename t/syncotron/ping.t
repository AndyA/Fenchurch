#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument;
use Fenchurch::Core::DB;
use Fenchurch::Syncotron::Ping;
use Storable qw( dclone );
use Test::Differences;
use Test::More;
use TestSupport;

preflight;

my $dbh = database("local");
$dbh->do("TRUNCATE `$_`") for qw( test_ping );

my $adh  = make_adhocument($dbh);
my $ping = Fenchurch::Syncotron::Ping->new(
  engine    => $adh,
  node_name => "test.local",
  ttl       => 5,
);

my @pings = (
  $ping->make_ping(
    origin_node => "test1.remote",
    ttl         => 10,
  ),
  $ping->make_ping(
    origin_node => "test2.remote",
    ttl         => 1,
  ),
  $ping->make_ping(
    origin_node => "test3.remote",
    ttl         => 3,
  ),
);

my @orig = map { dclone $_ } @pings;

$ping->put(@pings);

eq_or_diff [@pings], [@orig], "pings unchanged after put";

my @want = map { dclone $_ } @pings;
for my $ping (@want) {
  $ping->{ttl}--;
  push @{ $ping->{path} }, { node => "test.local", time => 1 };
}

{
  my @got = retime_ping( $ping->get_all );
  eq_or_diff [@got], [@want], "pings saved and loaded";
}

$pings[0]{status}{changed} = 1;
$ping->put( $pings[0] );
$want[0]{status}{changed} = 1;

{
  my @got = retime_ping( $ping->get_all );
  eq_or_diff [@got], [@want], "ping updated";
}

{
  my @got = $ping->get_for_remote("test1.remote");

  my $want = dclone $pings[-1];
  $want->{ttl}--;
  push @{ $want->{path} },
   {node => "test.local",
    time => $got[0]{path}[-1]{time} };

  eq_or_diff [@got], [$want];
}

done_testing;

sub make_adhocument {
  my $dbh = shift;

  my $db = Fenchurch::Core::DB->new(
    dbh     => $dbh,
    aliases => [ping => 'test_ping', lock => 'test_lock']
  );

  my $schema = Fenchurch::Adhocument::Schema->new(
    schema => test_data("schema.json") );

  return Fenchurch::Adhocument->new(
    db     => $db,
    schema => $schema
  );
}

sub retime_ping {
  retime_path( $_->{path} ) for @_;
  return @_;
}

sub retime_path {
  my $path = shift;
  my %tm   = ();
  $tm{ $_->{time} }++ for @$path;
  my $next = 1;
  $tm{$_} = $next++ for sort { $a <=> $b } keys %tm;
  $_->{time} = $tm{ $_->{time} } for @$path;
  return $path;
}

# vim:ts=2:sw=2:et:ft=perl

