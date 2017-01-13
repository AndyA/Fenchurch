#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use JSON;
use List::Util qw( shuffle );
use Storable qw( dclone freeze );
use Test::Differences;
use Test::More;
use TestSupport;
use Sanity;

use Fenchurch::Core::DB;
use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument::Versions;

preflight;

my @testlog = ();

sub pick_modifier {
  my $modify = shift;
  return $modify unless 'ARRAY' eq ref $modify;
  my $idx = randint @$modify;
  return pick_modifier( $modify->[$idx] );
}

sub create_doc {
  my ( $create, @args ) = @_;
  my ( $cr, @post ) = 'ARRAY' eq ref $create ? @$create : ($create);
  my $doc = $cr->(@args);
  for my $pp (@post) {
    my $ndoc = $pp->( $doc, @args );
    $doc = $ndoc if defined $ndoc;
  }
  return $doc;
}

sub test_versions($$$$$$) {
  my ( $desc, $ndocs, $nsteps, $schema, $create, $modify ) = @_;

  empty 'test_versions', map { $_->{table} } values %$schema;

  my $db = Fenchurch::Core::DB->new(
    dbh     => database,
    aliases => [versions => 'test_versions']
  );

  my $scm = Fenchurch::Adhocument::Schema->new( schema => $schema );

  my $ad = Fenchurch::Adhocument::Versions->new(
    schema => $scm,
    db     => $db,
  );

  my @ids = map { make_uuid() } 1 .. $ndocs;
  my @ver = map { [undef, create_doc( $create, $_, 1, $schema )] } @ids;

  for my $ver ( 2 .. $nsteps ) {

    # Write all the documents every time
    $ad->save( item => map { $_->[-1] } @ver );

    for my $doc (@ver) {
      my $mod  = pick_modifier($modify);
      my $prev = dclone $doc->[-1];
      my $next = $mod->( $prev, $ver, $schema );
      push @$doc, $next if defined $next;
    }
  }

  $ad->save( item => map { $_->[-1] } @ver );

  {
    my $got = [
      map {
        [map { $_->{doc} } @$_]
      } @{ $ad->versions( item => @ids ) }
    ];
    eq_or_diff $got, \@ver, "$desc: has expected versions";
  }

  # Delete one
  {
    $ad->delete( item => $ids[0] );
    push @{ $ver[0] }, undef;
    my $got = [
      map {
        [map { $_->{doc} } @$_]
      } @{ $ad->versions( item => @ids ) }
    ];
    eq_or_diff $got, \@ver,
     "$desc: has expected versions after one deletion";
    my $del = $ad->load( item => $ids[0] );
    eq_or_diff $del, [undef], "$desc: document was deleted";
  }

  # Now delete them all and check again - the version history should
  # still be intact with no duplicate deletions
  {
    $ad->delete( item => @ids );
    push @$_, undef for @ver[1 .. $#ver];
    my $got = [
      map {
        [map { $_->{doc} } @$_]
      } @{ $ad->versions( item => @ids ) }
    ];
    eq_or_diff $got, \@ver, "$desc: has expected versions after delete";
    my $del = $ad->load( item => @ids );
    eq_or_diff $del, [(undef) x @ids], "$desc: documents were deleted";
  }

  test_sanity( $ad->db );
}

sub make_item {
  my ( $uuid, $ver, $schema ) = @_;
  return {
    _uuid => $uuid,
    name  => "Version $ver"
  };
}

sub mod_none {
  my ( $prev, $ver, $schema ) = @_;
  return;    # means no new version
}

sub mod_item_name {
  my ( $prev, $ver, $schema ) = @_;
  $prev->{name} = "Version $ver";
  return $prev;
}

sub mod_add_tags {
  my $item  = shift;
  my $ntags = randint 3;
  $item->{tags} //= [];
  for ( 0 .. $ntags ) {
    my $idx = @{ $item->{tags} } ? $item->{tags}[-1]{index} + 1 : 0;
    push @{ $item->{tags} }, { index => $idx, name => "T\x{1f601}g $idx" };
  }
  return $item;
}

sub mod_remove_tag {
  my $item = shift;
  return unless @{ $item->{tags} // [] };
  my $idx = randint @{ $item->{tags} };
  splice @{ $item->{tags} }, $idx, 1;
  return $item;
}

sub mod_add_nodes {
  my $item   = shift;
  my $nnodes = randint 3;
  my @nd     = @{ $item->{nodes} // [] };
  for ( 0 .. $nnodes ) {
    my $uuid = make_uuid();
    push @nd, { _uuid => $uuid, name => "Node $uuid" };
  }
  $item->{nodes} = [sort { $a->{_uuid} cmp $b->{_uuid} } @nd];
  return $item;
}

sub mod_remove_node {
  my $item = shift;
  return unless @{ $item->{nodes} // [] };
  my $idx = randint @{ $item->{nodes} };
  splice @{ $item->{nodes} }, $idx, 1;
  return $item;
}

my @tbl_single = (
  item => {
    table => 'test_item',
    pkey  => '_uuid'
  }
);

my @tbl_tags = (
  tag => {
    table    => 'test_tag',
    child_of => { item => '_parent' },
    plural   => 'tags',
    order    => '+index'
  }
);

my @tbl_nodes = (
  node => {
    table    => 'test_tree',
    pkey     => '_uuid',
    child_of => { item => '_parent' },
    plural   => 'nodes'
  }
);

my $scm_single     = {@tbl_single};
my $scm_tags       = { @tbl_single, @tbl_tags };
my $scm_nodes      = { @tbl_single, @tbl_nodes };
my $scm_tags_nodes = { @tbl_single, @tbl_tags, @tbl_nodes };

use constant STEPS => 30;

test_versions 'Single simple document, no changes', 1, STEPS,
 $scm_single, \&make_item, \&mod_none;

test_versions 'Single simple document', 1, STEPS, $scm_single,
 \&make_item, [( \&mod_none ) x 2, \&mod_item_name];

test_versions 'Ten simple documents', 10, STEPS, $scm_single,
 \&make_item, [( \&mod_none ) x 2, \&mod_item_name];

test_versions 'Single document with constant tags', 1, STEPS, $scm_tags,
 [\&make_item, \&mod_add_tags], [( \&mod_none ) x 2, \&mod_item_name];

test_versions 'Ten documents with constant tags', 10, STEPS, $scm_tags,
 [\&make_item, \&mod_add_tags], [( \&mod_none ) x 2, \&mod_item_name];

test_versions 'Single document, adding tags', 1, STEPS, $scm_tags,
 [\&make_item, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_tags, \&mod_item_name];

test_versions 'Ten documents, adding tags', 10, STEPS, $scm_tags,
 [\&make_item, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_tags, \&mod_item_name];

test_versions 'Single document, adding / removing tags', 1, STEPS,
 $scm_tags, [\&make_item, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_tags, \&mod_remove_tag, \&mod_item_name];

test_versions 'Ten documents, adding / removing tags', 10, STEPS,
 $scm_tags, [\&make_item, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_tags, \&mod_remove_tag, \&mod_item_name];

test_versions 'Single document, adding nodes', 1, STEPS, $scm_nodes,
 [\&make_item, \&mod_add_nodes],
 [( \&mod_none ) x 2, \&mod_add_nodes, \&mod_item_name];

test_versions 'Ten documents, adding nodes', 10, STEPS, $scm_nodes,
 [\&make_item, \&mod_add_nodes],
 [( \&mod_none ) x 2, \&mod_add_nodes, \&mod_item_name];

test_versions 'Single document, adding / removing nodes', 1, STEPS,
 $scm_nodes, [\&make_item, \&mod_add_nodes],
 [( \&mod_none ) x 2, \&mod_add_nodes,
  \&mod_remove_node,  \&mod_item_name
 ];

test_versions 'Ten documents, adding / removing nodes', 10, STEPS,
 $scm_nodes, [\&make_item, \&mod_add_nodes],
 [( \&mod_none ) x 2, \&mod_add_nodes,
  \&mod_remove_node,  \&mod_item_name
 ];

test_versions 'Single document, adding tags / nodes', 1, STEPS,
 $scm_tags_nodes, [\&make_item, \&mod_add_nodes, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_nodes, \&mod_add_tags, \&mod_item_name];

test_versions 'Ten documents, adding tags / nodes', 10, STEPS,
 $scm_tags_nodes, [\&make_item, \&mod_add_nodes, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_nodes, \&mod_add_tags, \&mod_item_name];

test_versions 'Single document, adding / removing tags / nodes', 1,
 STEPS, $scm_tags_nodes, [\&make_item, \&mod_add_nodes, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_nodes,
  \&mod_add_tags,     \&mod_remove_node,
  \&mod_remove_tag,   \&mod_item_name
 ];

test_versions 'Ten documents, adding / removing tags / nodes', 10,
 STEPS, $scm_tags_nodes, [\&make_item, \&mod_add_nodes, \&mod_add_tags],
 [( \&mod_none ) x 2, \&mod_add_nodes,
  \&mod_add_tags,     \&mod_remove_node,
  \&mod_remove_tag,   \&mod_item_name
 ];

done_testing;

# vim:ts=2:sw=2:et:ft=perl

