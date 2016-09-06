#!perl

use strict;
use warnings;

use lib qw( t/lib );

use JSON;
use Test::Differences;
use Test::More;

use Lintilla::Core::Pipe;

{
  my $pipe = Lintilla::Core::Pipe->new;
  is $pipe->count, 0, 'empty pipe: count == 0';
  ok $pipe->is_empty, "and it's empty";
  is $pipe->get, undef, "and get returns nothing";

  $pipe->put( 1, 2, 3 );
  is $pipe->count, 3, 'three items in pipe';
  ok !$pipe->is_empty, "and it's not empty";
  is $pipe->get, 1, "get first item";
  eq_or_diff [$pipe->take], [2, 3], "get remaining items";

  $pipe->put( { name => 'a' }, { name => 'b' }, { name => 'c' } );
  eq_or_diff [$pipe->take(2)], [{ name => 'a' }, { name => 'b' }],
   "get two items";
  $pipe->put( { name => 'd' }, { name => 'e' }, { name => 'f' } );
  eq_or_diff [$pipe->take(2)], [{ name => 'c' }, { name => 'd' }],
   "get two more items";
}

done_testing();

# vim:ts=2:sw=2:et:ft=perl

