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
use JSON();
use LWP::UserAgent;
use POSIX qw( strftime );
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

sub ts { strftime '%Y/%m/%d %H:%M:%S', localtime }

sub trace {
  my ( $kind, $s_or_r, $msg ) = @_;
  my $ts   = ts();
  my $pad  = ' ' x length $ts;
  my @dump = split /\n/, JSON->new->pretty->canonical->encode($msg);
  say "$ts : [$kind $s_or_r]";
  say "$pad   $_" for @dump;
}

sub wire_app {
  my ( $kind, $app ) = @_;
  $app->on( send    => sub { trace( $kind, send    => @_ ) } );
  $app->on( receive => sub { trace( $kind, receive => @_ ) } );
}

$client->on( made_client => sub { wire_app( client => shift ) } );
$client->on( made_server => sub { wire_app( server => shift ) } );

while () {
  $client->next;
  sleep 1;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

