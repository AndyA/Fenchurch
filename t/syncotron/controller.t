#!perl

use lib qw( t/lib );

use JSON;
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;

preflight;

ok 1, "that's ok";

done_testing;

# vim:ts=2:sw=2:et:ft=perl

