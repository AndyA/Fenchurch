#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

my %UUID_MAP = ();

my $uuid_re = qr/
    ([0-9a-f]{8}) -
    ([0-9a-f]{4}) -
    ([0-9a-f]{4}) -
    ([0-9a-f]{4}) -
    ([0-9a-f]{12}) 
  /xi;

while (<>) {
  s/($uuid_re)/map_uuid($1)/eg;
  print;
}

sub map_uuid {
  my $uuid = shift;
  return $UUID_MAP{ lc $uuid } //= next_uuid();
}

sub next_uuid {
  state $next = 0;
  my $id = sprintf '%08x', ++$next;
  return format_uuid( $id x 4 );
}

sub format_uuid {
  my $uuid = shift;
  return join '-', $1, $2, $3, $4, $5
   if $uuid =~ /^ ([0-9a-f]{8}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{12}) $/xi;
  die "Bad UUID";
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

