#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use constant USAGE => <<EOT;
Usage: $0 <infile.pl> <outfile.pl>
EOT

die USAGE unless @ARGV == 2;

my ( $infile, $outfile ) = @ARGV;

my @lines = do { open my $fh, '<', $infile; <$fh> };
@lines[0] = "#!$^X\n";
{
  open my $fh, '>', $outfile;
  print $fh join '', @lines;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

