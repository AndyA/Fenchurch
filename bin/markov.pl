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
use JSON ();
use List::Util qw( shuffle );
use Text::HTMLCleaner;
use UUID::Tiny ':std';

use constant MAX_PAGE => 200;

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

my $sth = $dbh->prepare("SELECT `text` FROM `wiki_page`");
$sth->execute;
while ( my $row = $sth->fetchrow_hashref ) {
  my $tc = Text::HTMLCleaner->new( html => $row->{text} );
  $mc->add_sample( $tc->text );
}

my $sample = $mc->generate_sample;
$sample =~ s/^\s+//;
$sample =~ s/\s+$//;
my @words = shuffle split /\W+/, $sample;
my @slug = map lc, splice @words, 0, 3;

my $title = join " ", map ucfirst, @slug;
my $slug = join "-", @slug;

my $page = {
  uuid  => _make_uuid(),
  slug  => $slug,
  title => $title,
  text  => $sample
};

say JSON->new->pretty->canonical->encode($page);

$versions->save( page => $page );

# Prune
my @uuid
 = shuffle @{ $dbh->selectcol_arrayref("SELECT `uuid` FROM `wiki_page`")
 };

if ( @uuid > MAX_PAGE ) {
  splice @uuid, 0, MAX_PAGE;
  $versions->delete( page => @uuid );
}

sub _make_uuid { create_uuid_as_string(UUID_V4) }

# vim:ts=2:sw=2:sts=2:et:ft=perl

