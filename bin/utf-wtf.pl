#!/usr/bin/env perl

# Various encoding tests.

use v5.10;

use autodie;
use strict;
use warnings;

use Encode qw( encode decode );
use JSON::XS ();

STDOUT->binmode("UTF-8");

my $str = "Have \x{e4} nice day \x{1f601}";

show_str($str);

my $json = json();
my $js   = $json->encode($str);

show_str($js);

sub json { JSON::XS->new->utf8->allow_nonref->canonical }

sub show_str { say dump_str(@_) }

sub dump_str {
  my $str      = shift;
  my $safe_chr = sub {
    my $chr = shift;
    return "." unless utf8::is_utf8($str) || ord($chr) < 128;
    return "." if ord($chr) < 32 || ord($chr) == 127;
    return encode( "UTF-8", $chr );
  };
  my @chr = split //, $str;
  my @out = join ": ", ( utf8::is_utf8($str) ? "[UTF-8]" : "[BYTES]" ),
   encode( "UTF-8", $str );
  my $pos = 0;
  while (@chr) {
    my @cnk = splice @chr, 0, 8;
    my @row = ( sprintf "%08x :", $pos );
    push @row, map { sprintf " %08x", ord $_ } @cnk;
    push @row, ( " " x 9 ) x ( 8 - @cnk );
    push @row, " : ";
    push @row, map { $safe_chr->($_) } @cnk;
    $pos += @cnk;
    push @out, join "", @row;
  }
  return join "\n", @out;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

