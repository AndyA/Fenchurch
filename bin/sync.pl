#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use lib qw( ../Fenchurch/lib lib );

use Dancer qw( :script );
use Dancer::Plugin::Database;

use Fenchurch::Adhocument::Versions;
use Fenchurch::Core::DB;
use Fenchurch::Syncotron::HTTP::Client;
use Fenchurch::Syncotron::HTTP::Server;
use Fenchurch::Wiki::Engine;
use Fenchurch::Wiki::Schema;
use Getopt::Long;
use LWP::UserAgent;
use URI;

use constant USAGE => <<EOT;
Usage: $0 <remote-host>
EOT

GetOptions() or die USAGE;
@ARGV == 1   or die USAGE;

my $ep = URI->new( $ARGV[0] );
$ep->path("/sync");
say "Endpoint: $ep";

my $schema = Fenchurch::Wiki::Schema->new( dbh => database );
my $versions = Fenchurch::Adhocument::Versions->new(
  schema => $schema->schema,
  db     => $schema->db
);

my $client = Fenchurch::Syncotron::HTTP::Client->new(
  uri      => "$ep",
  versions => $versions
);

while () {
  $client->next;
  sleep 1;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

