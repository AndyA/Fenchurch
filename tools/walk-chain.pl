#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use lib qw( t/lib );

use TestSupport;

my $db = database;

# check_chain("test_chain");
check_chain("test_chain_linear");

sub check_chain {
  my $table  = shift;
  my ($want) = $db->selectrow_array("SELECT COUNT(*) FROM `$table`");
  my $got    = walk_chain( $db, $table, 1200 );

  say "$table: Wanted $want, got $got";
}

sub walk_chain {
  my ( $db, $table, $chunk ) = @_;

  my %seen = ();

  my @nodes = @{
    $db->selectcol_arrayref(
      join( " ",
        "SELECT tc1.uuid",
        "FROM `$table` AS tc1",
        "LEFT JOIN `$table` AS tc2 ON tc2.parent = tc1.uuid",
        "WHERE tc2.parent IS NULL",
        "ORDER BY tc1.serial ASC" )
    ) };

  if ( @nodes < $chunk ) {
    push @nodes,
     @{
      $db->selectcol_arrayref(
        "SELECT uuid FROM `$table` ORDER BY `rand` LIMIT ?",
        {}, $chunk - @nodes ) };
  }

  my $level = 0;
  while () {
    my @need = grep { !$seen{$_}++ } grep { defined } @nodes;
    last unless @need;
    printf "Level %5d, %5d nodes\n", $level, scalar @need;
    @nodes = @{
      $db->selectcol_arrayref(
        join( " ",
          "SELECT DISTINCT parent",
          "FROM `$table`",
          "WHERE uuid IN (",
          join( ", ", ("?") x @need ),
          ")" ),
        {},
        @need
      ) };
    $level++;
  }
  return scalar keys %seen;
}
