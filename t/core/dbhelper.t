#!perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;

preflight;

my $db = Fenchurch::Core::DB->new( dbh => database );

empty 'test_item';

{
  my @rec = map { { _uuid => make_uuid(), name => "Item $_" } } 1 .. 4;
  $db->insert( 'test_item', @rec );
  eq_or_diff read_back(), \@rec, "Records inserted";

  $_->{name} .= " (again)" for @rec;
  $db->replace( 'test_item', @rec );
  eq_or_diff read_back(), \@rec, "Records replaced";
}

done_testing;

sub read_back {
  return $db->selectall_arrayref(
    "SELECT * FROM {test_item} ORDER BY {name}",
    { Slice => {} } );
}

# vim:ts=2:sw=2:et:ft=perl

