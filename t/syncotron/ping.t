#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument;
use Fenchurch::Core::DB;
use Fenchurch::Syncotron::Ping;

preflight;

my $adh  = make_adhocument( database("local") );
my $ping = Fenchurch::Syncotron::Ping->new(
  engine    => $adh,
  node_name => "test.local",
  ttl       => 5,
);

my @pings = (
  { origin_node => "test1.remote", ttl => 10, path => [], status => {} },
  { origin_node => "test2.remote", ttl => 1,  path => [], status => {} },
  { origin_node => "test3.remote", ttl => 3,  path => [], status => {} },
);

$ping->put(@pings);

my @got = $ping->get_all;
eq_or_diff [@got], [@pings], "pings saved and loaded";

done_testing;

sub make_adhocument {
  my $dbh = shift;

  $dbh->do("TRUNCATE `$_`") for qw( test_ping );

  my $db = Fenchurch::Core::DB->new(
    dbh     => $dbh,
    aliases => [ping => 'test_ping']
  );

  my $schema = Fenchurch::Adhocument::Schema->new(
    schema => test_data("schema.json") );

  return Fenchurch::Adhocument->new(
    db     => $db,
    schema => $schema
  );
}

# vim:ts=2:sw=2:et:ft=perl

