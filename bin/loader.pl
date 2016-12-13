#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use lib qw( lib );

use String::Markov;

use Dancer qw( :script );
use Dancer::Plugin::Database;
use Fenchurch::Adhocument::Versions;
use Fenchurch::Wiki::Engine;
use Fenchurch::Wiki::Schema;
use File::Find;
use UUID::Tiny ':std';

STDOUT->binmode("UTF-8");

my $dbh = database;

my $schema = Fenchurch::Wiki::Schema->new( dbh => $dbh );
my $versions = Fenchurch::Adhocument::Versions->new(
  schema => $schema->schema,
  db     => $schema->db
);

my $mc = String::Markov->new(
  split_sep => qr{\s+},
  join_sep  => ' ',
  order     => 2
);

find sub {
  return if /^\./;
  return unless -f;
  my $name = $_;
  my $txt = do { local $/; open my $fh, '<', $name; <$fh> };
  ( my $slug = $File::Find::name ) =~ s/\W+/-/g;
  $slug =~ s/^-+//g;
  $slug =~ s/-+$//g;
  say $slug;

  my $page = {
    uuid  => make_uuid(),
    slug  => $slug,
    title => $name,
    text  => $txt
  };

  $versions->save( page => $page );

}, @ARGV;

sub make_uuid { create_uuid_as_string(UUID_V4) }

# vim:ts=2:sw=2:sts=2:et:ft=perl
