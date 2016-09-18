#!perl

use v5.10;

use autodie;
use strict;
use warnings;

use lib qw( t/lib );

use JSON ();
use Test::Differences;
use Test::More;
use TestSupport;
use Scalar::Util qw( looks_like_number );

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument;
use Fenchurch::Core::DB;

preflight;

empty('test_programmes_v2');

my $programmes = test_data("stash.json");

{
  my $ad = Fenchurch::Adhocument->new(
    schema => schema(),
    db     => Fenchurch::Core::DB->new( dbh => database )
  );

  $ad->save( programme => @$programmes );
  my $got = $ad->load( programme => map { $_->{_uuid} } @$programmes );
  eq_or_diff $got, $programmes, "no numify: save, load OK";
}

{
  my $ad = Fenchurch::Adhocument->new(
    schema => schema(),
    db     => Fenchurch::Core::DB->new( dbh => database ),
    numify => 1
  );

  my $numified = numify($programmes);

  my $got = $ad->load( programme => map { $_->{_uuid} } @$programmes );
  eq_or_diff $got, $numified, "numify: load OK";
}

done_testing;

sub numify {
  my $obj = shift;
  unless ( ref $obj ) {
    return $obj unless defined $obj;
    return 0 + $obj if looks_like_number $obj;
    return $obj;
  }

  return [map { numify($_) } @$obj]
   if 'ARRAY' eq ref $obj;

  return { map { $_ => numify( $obj->{$_} ) } keys %$obj }
   if 'HASH' eq ref $obj;

  die;
}

sub schema {
  return Fenchurch::Adhocument::Schema->new(
    schema => test_data("schema.json") );
}

# vim:ts=2:sw=2:et:ft=perl

