#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Storable qw( dclone );
use Sys::Hostname;
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;
use Fenchurch::Adhocument;
use Fenchurch::Adhocument::Resolver;
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

  my @docs = (
    { _uuid => "9531e3af-fc61-49eb-b047-bf32b834c94e",
      name  => "Test item 1",
      tags =>
       [{ index => "1", name => "test" }, { index => "2", name => "item" }],
      nodes => []
    },
    { _uuid => "221fe567-d4db-42e8-b354-b00baba07823",
      name  => "Test item 2",
      tags =>
       [{ index => "1", name => "test" }, { index => "2", name => "item" }],
      nodes => []
    },
    { _uuid => "4e57c124-c805-496f-a306-f332a1a0dc65",
      name  => "Test item 3",
      tags =>
       [{ index => "1", name => "test" }, { index => "2", name => "item" }],
      nodes => [] }
  );

  my @edits = ( {
      # A non-conflicted edit
      uuid     => "97bdc861-495a-4545-9b67-f87293915078",
      parent   => undef,
      serial   => 1,
      node     => "testbox",
      object   => $docs[0]{_uuid},
      when     => "2016-03-15 15:57:10",
      sequence => 1,
      rand     => 0.832925612430216,
      kind     => "item",
      schema   => $schema,
      old_data => $docs[0],
      new_data => {
        _uuid => $docs[0]{_uuid},
        name  => "Test item 1 - edited",
        tags  => [{ index => "1", name => "edited" }],
        nodes => [] }

    }, {
      # Conflict: edit assumes document doesn't exist
      uuid     => "13242b35-4f79-4b82-8def-aa2494078ec5",
      parent   => "97bdc861-495a-4545-9b67-f87293915078",
      serial   => 2,
      node     => "testbox",
      object   => $docs[1]{_uuid},
      when     => "2016-03-15 16:31:11",
      sequence => 1,
      rand     => 0.547019014496147,
      kind     => "item",
      schema   => $schema,
      old_data => undef,
      new_data => $docs[1]
    }, {
      # Conflict: edit assumes missing document exists
      uuid     => "fbd0eda4-8b5d-49e6-96d8-2e192f362b2b",
      parent   => "13242b35-4f79-4b82-8def-aa2494078ec5",
      serial   => 3,
      node     => "testbox",
      object   => "0b7da10d-7668-4fe6-b087-ee10b52a4a43",
      when     => "2016-03-15 16:25:24",
      sequence => 1,
      rand     => 0.49396452428217,
      kind     => "item",
      schema   => $schema,
      old_data => {
        _uuid => "4364ed63-310d-4315-83b2-ec60e1ed4296",
        name  => "Test item 4",
        tags =>
         [{ index => "1", name => "test" }, { index => "2", name => "item" }],
        nodes => []
      },
      new_data => {
        _uuid => "4364ed63-310d-4315-83b2-ec60e1ed4296",
        name  => "Test item 4 edited",
        tags  => [{ index => "1", name => "edited" }],
        nodes => [] }
    }, {
      # Conflict: old data mismatch on edit
      uuid     => "25ea887d-51d1-4698-b153-ba790035be8a",
      parent   => "fbd0eda4-8b5d-49e6-96d8-2e192f362b2b",
      serial   => 4,
      node     => "testbox",
      object   => $docs[2]{_uuid},
      when     => "2016-03-15 16:25:24",
      sequence => 1,
      rand     => 0.780788111124771,
      kind     => "item",
      schema   => $schema,
      old_data => {
        _uuid => $docs[2]{_uuid},
        name  => "Test item 3 name mismatch",
        tags  => [{ index => "1", name => "test" }],
        nodes => []
      },
      new_data => {
        _uuid => $docs[2]{_uuid},
        name  => "Test item 3 edited",
        tags  => [{ index => "1", name => "edited" }],
        nodes => [] } }
  );

  empty 'test_versions', 'test_conflicts',
   map { $_->{table} } values %$schema;

  my $adh = make_adhocument( database, $schema );
  $adh->save( item => @docs );

  my ( $ver, $conflicts ) = make_versions( database, $schema );

  my $index = $ver->apply( 0, \@edits );

  is $index, 4, "index updated";

  my $stash = $conflicts->since( 0, 10 );

  my @want = (
    { kind     => "item",
      new_data => undef,
      node     => hostname,
      object   => "221fe567-d4db-42e8-b354-b00baba07823",
      old_data => {
        _uuid => "221fe567-d4db-42e8-b354-b00baba07823",
        name  => "Test item 2",
        nodes => [],
        tags  => [
          { index => "1",
            name  => "test"
          },
          { index => "2",
            name  => "item"
          }
        ]
      },
      schema   => $schema,
      sequence => 1,
      serial   => 1,
    },
    { kind     => "item",
      new_data => {
        _uuid => "4364ed63-310d-4315-83b2-ec60e1ed4296",
        name  => "Test item 4",
        nodes => [],
        tags  => [
          { index => "1",
            name  => "test"
          },
          { index => "2",
            name  => "item"
          }
        ]
      },
      node     => hostname,
      object   => "4364ed63-310d-4315-83b2-ec60e1ed4296",
      old_data => undef,
      schema   => $schema,
      sequence => 1,
      serial   => 2,
    },
    { kind     => "item",
      new_data => {
        _uuid => "4e57c124-c805-496f-a306-f332a1a0dc65",
        name  => "Test item 3 name mismatch",
        nodes => [],
        tags  => [
          { index => "1",
            name  => "test"
          }
        ]
      },
      node     => hostname,
      object   => "4e57c124-c805-496f-a306-f332a1a0dc65",
      old_data => {
        _uuid => "4e57c124-c805-496f-a306-f332a1a0dc65",
        name  => "Test item 3",
        nodes => [],
        tags  => [
          { index => "1",
            name  => "test"
          },
          { index => "2",
            name  => "item"
          }
        ]
      },
      schema   => $schema,
      sequence => 1,
      serial   => 3,
    }
  );

  eq_or_diff strip_edits($stash), strip_edits( [@want] ), "edits match";

  # use Data::Dumper;
  # my $d = Data::Dumper->new([$stash], ["$stash"]);
  # $d->Useqq(1)->Quotekeys(0)->Sortkeys(1);
  # print $d->Dump;
}

done_testing();

sub strip_edits {
  my $edits = shift;
  my @out   = ();
  for my $edit (@$edits) {
    my $e2 = dclone $edit;
    delete @{$e2}{ 'when', 'rand', 'uuid', 'parent' };
    push @out, $e2;
  }
  return \@out;
}

sub make_adhocument {
  my ( $dbh, $schema ) = @_;

  my $db = Fenchurch::Core::DB->new( dbh => $dbh );

  my $scm = Fenchurch::Adhocument::Schema->new(
    schema => $schema,
    db     => $db
  );

  return Fenchurch::Adhocument->new(
    schema => $scm,
    db     => $db,
  );
}

sub make_versions {
  my ( $dbh, $schema ) = @_;

  my $db = Fenchurch::Core::DB->new(
    dbh    => $dbh,
    tables => { versions => 'test_versions' }
  );

  my $scm = Fenchurch::Adhocument::Schema->new(
    schema => $schema,
    db     => $db
  );

  my $conflicts = Fenchurch::Adhocument::Versions->new(
    schema => $scm,
    db     => Fenchurch::Core::DB->new(
      dbh    => $dbh,
      tables => { versions => 'test_conflicts' }
    )
  );

  my $resolver
   = Fenchurch::Adhocument::Resolver->new( engine => $conflicts );

  my $ver = Fenchurch::Adhocument::Versions->new(
    schema            => $scm,
    db                => $db,
    conflict_resolver => $resolver
  );

  return ( $ver, $conflicts );
}

# vim:ts=2:sw=2:et:ft=perl
