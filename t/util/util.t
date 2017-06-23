#!perl

use strict;
use warnings;

use Test::More;
use Test::Differences;

use Fenchurch::Util qw( tidy trim unique );

is tidy(" Oh   look!   "), "Oh look!",   "tidy";
is trim(" Oh   look!   "), "Oh   look!", "trim";

eq_or_diff [unique( "A", "B", "C", "B", "A", "D" )],
 ["A", "B", "C", "D"], "unique";

done_testing();

# vim:ts=2:sw=2:et:ft=perl

