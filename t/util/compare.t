#!perl

use strict;
use warnings;

use Test::Differences;
use Test::More;

use Fenchurch::Util::Compare qw( same );

ok same( undef, undef ), "undef == undef";
ok !same( undef, 1 ), "undef != 1";
ok same( 1,     1 ),   "1 == 1";
ok same( '1',   1 ),   "'1' == 1";
ok same( 1,     '1' ), "1 == '1'";
ok same( '1.0', 1 ),   "'1.0' == 1";
ok !same( {}, 0 ), "{} != 0";
ok same( [1, 2, 3], ['1.0', 2, 3] ), "[1, 2, 3] == ['1.0', 2, 3]";
ok !same( [1, 2, 3], ['1.0', 2, 4] ), "[1, 2, 3] != ['1.0', 2, 4]";
ok same( { a => 1 }, { a => '1.0' } ), "{ a => 1 } == { a => '1.0' }";
ok !same( { a => 2 }, { a => '1.0' } ), "{ a => 2 } != { a => '1.0' }";

done_testing;

# vim:ts=2:sw=2:et:ft=perl

