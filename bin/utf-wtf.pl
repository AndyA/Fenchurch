#!/usr/bin/env perl

# Various encoding tests.

use v5.10;

use autodie;
use strict;
use warnings;

use Encode qw( encode decode );
use JSON::XS ();
use DBI;

STDOUT->binmode("UTF-8");

my $str = "Have \x{e4} nice day \x{1f601}";

show_str($str);

my $json = json();
my $js   = $json->encode($str);

show_str($js);

{
  my $dbh = dbh(
    host => 'localhost',
    db   => 'utf_wtf',
    user => 'root',
    pass => ''
  );

  my @vars = (
    "character_set_client",  "character_set_connection",
    "character_set_results", "character_set_database",
    "character_set_server"
  );

  set_all( $dbh, "latin1", @vars );

  if (1) {

    $dbh->do("TRUNCATE `utf_wtf`");

    for my $data ( ["String", $str], ["JSON", $js] ) {
      my ( $kind, $dat ) = @$data;
      $dbh->do(
        "INSERT INTO `utf_wtf` (`latin`, `utf`, `kind`) VALUES (?, ?, ?)",
        {}, $dat, $dat, $kind );
    }

    my $got = $dbh->selectall_arrayref( "SELECT * FROM `utf_wtf`",
      { Slice => {} } );

    for my $row (@$got) {
      my $kind = delete $row->{kind};
      for my $fld ( sort keys %$row ) {
        say "\n$kind $fld:";
        show_str( $row->{$fld} );
        if ( $kind eq 'JSON' ) {
          my $dec = eval { $json->decode( encode( "UTF-8", $row->{$fld} ) ) };
          show_str($dec) unless $@;
        }
      }
    }
  }

  if (0) {

    my ($syn)
     = $dbh->selectrow_array(
      "SELECT `synopsis` FROM genome3.genome_programmes_v2 WHERE _uuid = ?",
      {}, "1ebcecad-fba9-4976-97e3-1337dd879e4a" );

    show_str($syn);
  }

  $dbh->disconnect;
}

sub set_all {
  my ( $dbh, $val, @var ) = @_;
  for my $var ( sort @var ) {
    say "SET $var = $val;";
    $dbh->do("SET $var = $val");
  }
}

sub json { JSON::XS->new->utf8->allow_nonref->canonical }
#sub json { JSON::XS->new->allow_nonref->canonical }

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

sub dbh {
  my %db = @_;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db{db}, $db{host} ),
    $db{user},
    $db{pass},
    { mysql_enable_utf8 => 1,
      RaiseError        => 1
    }
  );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

