#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use JSON;
use Test::Differences;
use Test::More;
use TestSupport;
use Storable qw( dclone );
use Sys::Hostname;

use Fenchurch::Core::DB;
use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument::Versions;

preflight;

{
  my $schema = {
    item => { table => 'test_item', },
    tag  => {
      table    => 'test_tag',
      child_of => { item => '_parent' },
      plural   => 'tags',
      order    => '+index'
    },
    node => {
      table    => 'test_tree',
      child_of => { item => '_parent' },
      plural   => 'nodes'
    } };

  my ( $uuid, @versions ) = make_versions();
  my @edits;

  {
    my $db = Fenchurch::Core::DB->new( dbh => database );

    my $scm = Fenchurch::Adhocument::Schema->new(
      schema => $schema,
      db     => $db
    );

    my $ad = Fenchurch::Adhocument::Versions->new(
      schema        => $scm,
      db            => $db,
      version_table => 'test_versions'
    );

    # Capture some edits to a document
    #

    empty 'test_versions', map { $_->{table} } values %$schema;

    eq_or_diff $ad->since(0), [], "no changes";

    my ( $seq, $old_rec ) = ( 1, undef );

    for my $rec (@versions) {

      if ( defined $rec ) {
        $ad->save( item => $rec );
      }
      else {
        $ad->delete( item => $uuid );
      }

      my $want = [
        { kind     => 'item',
          node     => hostname,
          new_data => $rec,
          object   => $uuid,
          old_data => $old_rec,
          schema   => $schema,
          sequence => $seq,
          serial   => $seq,
        }
      ];

      my $got = $ad->since( $seq - 1 );
      push @edits, dclone $got;
      delete @{$_}{ "when", "uuid", "parent", "rand" } for @$got;
      eq_or_diff $got, $want, "change at stage $seq";

      my $docs = $ad->load( item => $uuid );
      eq_or_diff $docs, [$rec], "document at stage $seq";

      ( $seq, $old_rec ) = ( $seq + 1, $rec );
    }
  }

  {
    my $db = Fenchurch::Core::DB->new( dbh => database );

    my $scm = Fenchurch::Adhocument::Schema->new(
      schema => $schema,
      db     => $db
    );

    my $ad = Fenchurch::Adhocument::Versions->new(
      schema        => $scm,
      db            => $db,
      version_table => 'test_versions',
      node_name     => 'test node'
    );

    # Replay edits and check consistency
    #

    empty 'test_versions', map { $_->{table} } values %$schema;

    my $seq = 1;
    for my $stash (@edits) {
      my $next = $ad->apply( $seq - 1, $stash );
      is $next, $seq, "serial matches at stage $seq";

      my $docs = $ad->load( item => $uuid );
      my $rec = shift @versions;
      eq_or_diff $docs, [$rec], "edited document at stage $seq";

      $seq++;
    }

    my $done_edits = [map { @$_ } @edits];
    my $new_edits = $ad->since(0);
    eq_or_diff strip_when($new_edits), strip_when($done_edits),
     "edits match";

    # Now attempt to apply the same edits again - which should
    # be silently ignored
    my $next = $ad->apply( 0, $done_edits );
    is $next, $seq - 1, "duplicate edits ignored";
  }
}

done_testing();

sub strip_when {
  my $edits = shift;
  my @out   = ();
  for my $edit (@$edits) {
    my $e2 = dclone $edit;
    delete @{$e2}{ 'when', 'rand' };
    push @out, $e2;
  }
  return \@out;
}

sub make_versions {
  my @versions = ();
  my $uuid     = make_uuid();

  my $rec = {
    _uuid => $uuid,
    name  => "Test item",
    tags => [{ index => 1, name => "test" }, { index => 2, name => "item" }],
    nodes => [
      sort { $a->{_uuid} cmp $b->{_uuid} } (
        { _uuid => make_uuid(), name => "Node 1" },
        { _uuid => make_uuid(), name => "Node 2" }
      )
    ] };
  push @versions, dclone $rec;

  # remove a node
  my $node = shift @{ $rec->{nodes} };
  push @versions, dclone $rec;

  # add a tag
  push @{ $rec->{tags} }, { index => 3, name => "added" };
  push @versions, dclone $rec;

  # replace node
  unshift @{ $rec->{nodes} }, $node;
  push @versions, dclone $rec;

  # change name, remove tag
  $rec->{name} = "Updated test item";
  shift @{ $rec->{tags} };
  push @versions, dclone $rec;

  # delete
  push @versions, undef;

  return ( $uuid, @versions );
}

# vim:ts=2:sw=2:et:ft=perl
