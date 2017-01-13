package Sanity;

use strict;
use warnings;

use Test::Differences;
use TestSupport;

use Fenchurch::Adhocument::Sanity::Tree;
use Fenchurch::Adhocument::Sanity::Report;

require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
 check_sanity test_sanity
);

sub check_sanity {
  my $db = shift // Fenchurch::Core::DB->new(
    dbh     => database,
    aliases => [versions => 'test_versions']
  );

  my $ts = Fenchurch::Adhocument::Sanity::Tree->new(
    db    => $db,
    since => 0
  );

  $ts->check;
  return $ts->report->get_log;
}

sub test_sanity {
  my @log = check_sanity(@_);
  eq_or_diff [@log], [], "Fenchurch data is sane";
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
