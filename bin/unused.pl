#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use File::Find;

my %packages = ();

with_file(
  sub {
    my ( $name, $fh ) = @_;
    while (<$fh>) {
      next unless /^\s*package\s+(\S+)\s*;/;
      $packages{$1}++;
    }
  },
  'lib'
);

my $all_but = sub {
  my %exclude = map { $_ => 1 } @_;
  my $pat = join "|", map quotemeta,
   grep { !$exclude{$_} } sort keys %packages;
  my $re = qr{(?<![\w\d:])($pat)(?![\w\d:])};
  return $re;
};

with_file(
  sub {
    my ( $name, $fh ) = @_;
    my $re = $all_but->();
    while (<$fh>) {
      chomp( my $line = $_ );
      if ( $line =~ /^\s*package\s+(\S+)\s*;/ ) {
        # Exclude self
        $re = $all_but->($1);
        next;
      }
      while ( $line =~ /$re/g ) {
        delete $packages{$1};
      }
    }
  },
  'lib',
  't',
  'bin'
);

say for sort keys %packages;

sub with_file {
  my ( $cb, @dir ) = @_;
  find sub {
    return if /^\./;
    return unless -f $_;
    open my $fh, '<', $_;
    $cb->( $File::Find::name, $fh );
    close $fh;
  }, @dir;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
