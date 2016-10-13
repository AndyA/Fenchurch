#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use Dancer qw( :script );
use Dancer::Plugin::Database;

debug_versions(database);

# Some debug
sub debug_versions {
  my $dbh  = shift;
  my $vers = $dbh->selectall_arrayref(
    join( " ",
      "SELECT `uuid`, `parent`, `kind`, `object`, `serial`, `sequence`, `when`",
      "  FROM `fenchurch_versions`",
      " ORDER BY `serial`" ),
    { Slice => {} }
  );
  my %by_uuid = ();
  for my $ver (@$vers) {
    $by_uuid{ $ver->{uuid} } = $ver;
  }
  my @root = ();
  for my $ver (@$vers) {
    if ( defined $ver->{parent} ) {
      my $parent = $by_uuid{ $ver->{parent} };
      push @{ $parent->{children} }, $ver;
    }
    else {
      push @root, $ver;
    }
  }
  say "Version tree:";
  show_versions( 0, @root );
}

sub show_versions {
  my $indent = shift // 0;
  my $pad = "  " x $indent;
  for my $ver (@_) {
    say $pad, join " ",
     @{$ver}{ 'kind', 'uuid', 'object', 'serial', 'sequence', 'when' };
    show_versions( $indent + 1, @{ $ver->{children} // [] } );
  }
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

