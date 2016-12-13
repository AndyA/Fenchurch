#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;
use Test::Differences;
use TestSupport;

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument::Versions;
use Fenchurch::Adhocument;
use Fenchurch::Core::DB;

preflight;

empty 'test_versions', 'test_item';

test_extra_rejected( make_adhocument( common_options() ) );
test_extra_rejected( make_adhocument_versions( common_options() ) );
test_extra_allowed(
  make_adhocument( common_options(), ignore_extra_columns => 1 ) );
test_extra_allowed(
  make_adhocument_versions( common_options(), ignore_extra_columns => 1 )
);
test_extra_allowed(
  make_adhocument( common_options( ignore_extra_columns => 1 ) ) );
test_extra_allowed(
  make_adhocument_versions( common_options( ignore_extra_columns => 1 ) )
);

sub test_extra_rejected {
  my $ad   = shift;
  my $kind = ref $ad;

  my $item = {
    _uuid => make_uuid(),
    name  => "An item",
    extra => "Not allowed"
  };

  eval { $ad->save( item => $item ) };
  ok $@, "$kind: error thrown";
  like $@, qr{not found}, "$kind: message matches";
}

sub test_extra_allowed {
  my $ad   = shift;
  my $kind = ref $ad;

  my $want = { _uuid => make_uuid(), name => "An item" };
  my $item = { %$want, extra => "Allowed" };

  eval { $ad->save( item => $item ) };
  ok !$@, "$kind: no error thrown";

  my $got = $ad->load( item => $item->{_uuid} )->[0];
  eq_or_diff $got, $want, "$kind: saved OK";
}

done_testing;

sub common_options {
  my %options = @_;

  my $schema = {
    item => {
      table   => 'test_item',
      pkey    => '_uuid',
      options => \%options,
    } };

  my $db = Fenchurch::Core::DB->new(
    dbh     => database,
    aliases => [versions => 'test_versions']
  );

  my $scm = Fenchurch::Adhocument::Schema->new( schema => $schema );

  return (
    schema => $scm,
    db     => $db,
  );
}

sub make_adhocument {
  return Fenchurch::Adhocument->new(@_);
}

sub make_adhocument_versions {
  return Fenchurch::Adhocument::Versions->new(@_);
}

# vim:ts=2:sw=2:et:ft=perl
