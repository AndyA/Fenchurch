#!perl

use strict;
use warnings;
use Test::More;
use JSON ();

use Fenchurch::CouchDB::Database;
use Fenchurch::CouchDB;
use UUID::Tiny;

if (0) {

  my $db = Fenchurch::CouchDB::Database->new( name => "fenchurch-test" );

  my $JSON = JSON->new->pretty->canonical;

  $db->delete if $db->exists;
  $db->create;

  my $uuid = make_uuid();
  my $doc = { name => "Test document", value => [1, 2, 3] };
  $JSON->encode( $db->put( $uuid, $doc ) );
  $JSON->encode( my $resp = $db->get($uuid) );
  $doc->{keywords} = ["testing"];
  $doc->{_rev}     = $resp->{_rev};
  $JSON->encode( $db->put( $uuid, $doc ) );
  $JSON->encode( $db->get($uuid) );

  $db->delete;
}

ok 1, "that's ok";

done_testing;

sub make_uuid { UUID::Tiny::create_uuid_as_string(UUID::Tiny::UUID_V4) }

# vim:ts=2:sw=2:et:ft=perl

