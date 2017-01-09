#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;

use Fenchurch::Util::Data qw( flatten );

ok 1, "that's ok";
eq_or_diff [flatten "Hello"], ["Hello"], "flatten - single scalar";
eq_or_diff [flatten "Hello", "World"], ["Hello", "World"],
 "flatten - two scalars";
eq_or_diff [flatten ["Hello", "World"]], ["Hello", "World"],
 "flatten - array";
eq_or_diff [flatten ["Hello"], ["World"]], ["Hello", "World"],
 "flatten - two arrays";

done_testing;

# vim:ts=2:sw=2:et:ft=perl

