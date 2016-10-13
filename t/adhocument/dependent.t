#!perl

use v5.10;

use autodie;
use strict;
use warnings;

use lib qw( t/lib );

use Storable qw( dclone );
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Adhocument::Schema;
use Fenchurch::Adhocument::Versions;
use Fenchurch::Adhocument;
use Fenchurch::Core::DB;

preflight;

my @tables = qw(
 test_contributors
 test_edit
 test_programmes_v2
 test_related
 test_versions
);

empty(@tables);

my $programmes = test_data("stash.json");

{
  my $ad = Fenchurch::Adhocument->new(
    schema => schema(),
    db     => Fenchurch::Core::DB->new( dbh => database )
  );

  $ad->save( programme => @$programmes );
}

{
  my $adv = Fenchurch::Adhocument::Versions->new(
    schema => schema(),
    db     => Fenchurch::Core::DB->new(
      dbh    => database,
      tables => { versions => 'test_versions' }
    ),
  );

  # Business logic: when an edit moves to 'accepted' apply it; when it
  # moves out of 'accepted' roll it back.

  $adv->on(
    version => sub {
      my $vers = shift;

      for my $ver (@$vers) {
        if ( $ver->{kind} eq "edit" ) {
          my $edit      = $ver->{new_data};
          my $old_state = $ver->{old_data}{state} // "missing";
          my $new_state = $edit->{state} // "deleted";

          my %common = ( context => { edit => $edit } );

          if ( $old_state ne "accepted" && $new_state eq "accepted" ) {
            # Accepting
            $adv->save(
              { %common, parents => [$ver->{uuid}], expect => [$edit->{old_data}] },
              $edit->{kind}, $edit->{new_data} );
          }
          elsif ( $old_state eq "accepted" && $new_state ne "accepted" ) {
            # Rejecting
            $adv->save(
              { %common, parents => [$ver->{uuid}], expect => [$edit->{new_data}] },
              $edit->{kind}, $edit->{old_data} );
          }
          elsif ( $old_state eq "accepted" && $new_state eq "accepted" ) {
            die "Can't alter an edit while it is applied";
          }

        }
      }
    }
  );

  my @orig = (
    dclone $programmes->[0],
    dclone $programmes->[1],
    dclone $programmes->[2]
  );

  my @prog = (
    dclone $programmes->[0],
    dclone $programmes->[1],
    dclone $programmes->[2]
  );

  # Make some changes
  push @{ $prog[0]{contributors} },
   {code       => undef,
    first_name => "Kathryn",
    group      => "crew",
    index      => "2",
    kind       => "member",
    last_name  => "Simm\x{c3}nds.",
    type       => "Unknown"
   };

  $prog[0]{title} = "The F\x{c3}undati\x{c3}ns \x{c3}f Music";

  push @{ $prog[2]{contributors} },
   {code       => undef,
    first_name => "Gene",
    group      => "crew",
    index      => "15",
    kind       => "member",
    last_name  => "Simm\x{c3}ns.",
    type       => "Unknown"
   };

  $prog[2]{title} = "Kiss: The Wilderness Years";

  {
    # Three edits that should succeed
    my @edit = ();
    for my $i ( 0 .. $#prog ) {
      push @edit,
       {uuid     => make_uuid(),
        kind     => 'programme',
        object   => $prog[$i]{_uuid},
        state    => 'pending',
        old_data => $orig[$i],
        new_data => $prog[$i] };
    }

    $adv->save( edit => @edit );

    eq_or_diff $adv->load( edit => map { $_->{uuid} } @edit ), [@edit],
     "edit saved OK";

    $_->{state} = 'review' for @edit;
    $adv->save( edit => @edit );

    $_->{state} = 'accepted' for @edit;
    $adv->save( edit => @edit );

    # Check programme
    eq_or_diff $adv->load( programme => map { $_->{_uuid} } @prog ), [@prog],
     "programme edited OK";

    eq_or_diff [
      count_versions( $adv, programme => map { $_->{_uuid} } @prog )
     ],
     [2, 1, 2],
     "apply: expected number of programme versions";

    eq_or_diff [count_versions( $adv, edit => map { $_->{uuid} } @edit )],
     [4, 4, 4],
     "apply: expected number of edit versions";

    $_->{state} = 'rejected' for @edit;
    $adv->save( edit => @edit );

    eq_or_diff $adv->load( programme => map { $_->{_uuid} } @prog ), [@orig],
     "programme reverted OK";

    eq_or_diff [
      count_versions( $adv, programme => map { $_->{_uuid} } @prog )
     ],
     [3, 1, 3],
     "revert: expected number of programme versions";

    eq_or_diff [count_versions( $adv, edit => map { $_->{uuid} } @edit )],
     [5, 5, 5],
     "revert: expected number of edit versions";

    $_->{state} = 'accepted' for @edit;
    $adv->save( edit => @edit );

    eq_or_diff $adv->load( programme => map { $_->{_uuid} } @prog ), [@prog],
     "programme edited again OK";

    eq_or_diff [
      count_versions( $adv, programme => map { $_->{_uuid} } @prog )
     ],
     [4, 1, 4],
     "apply(2): expected number of programme versions";

    eq_or_diff [count_versions( $adv, edit => map { $_->{uuid} } @edit )],
     [6, 6, 6],
     "apply(2): expected number of edit versions";
  }

  {
    my @edit = ();
    for my $i ( 0 .. $#prog ) {
      push @edit,
       {uuid     => make_uuid(),
        kind     => 'programme',
        object   => $prog[$i]{_uuid},
        state    => 'pending',
        old_data => $prog[$i],
        new_data => $orig[$i],
       };
    }

    $adv->save( edit => @edit );

    $_->{state} = 'accepted' for @edit;
    $adv->save( edit => @edit );

    # Check programme
    eq_or_diff $adv->load( programme => map { $_->{_uuid} } @prog ), [@orig],
     "programme edited OK";

    eq_or_diff [
      count_versions( $adv, programme => map { $_->{_uuid} } @prog )
     ],
     [5, 1, 5],
     "expected number of programme versions";

    eq_or_diff [count_versions( $adv, edit => map { $_->{uuid} } @edit )],
     [3, 3, 3],
     "expected number of edit versions";
  }

  {
    my @edit = ();
    for my $i ( 0 .. $#prog ) {
      push @edit,
       {uuid     => make_uuid(),
        kind     => 'programme',
        object   => $prog[$i]{_uuid},
        state    => 'pending',
        old_data => dclone $orig[$i],
        new_data => $prog[$i],
       };
    }

    # Make the third edit fail
    $edit[2]{old_data}{title} = "Oops!";

    $adv->save( edit => @edit );

    # Attempt to accept the batch of edits. None of them should
    # be accepted because the last of the batch has a mismatched
    # expectation
    $_->{state} = 'accepted' for @edit;
    my $events = 0;
    $adv->on(
      conflict => sub {
        my ( $kind, $got, $wanted, $context ) = @_;
        ok $context->{edit}, "Context passed to conflict handler";
        $events++;
      }
    );
    eval { $adv->save( edit => @edit ) };
    like $@, qr{Document\s+\[}, "error thrown";
    $adv->off('conflict');
    is $events, 1, "conflict event emitted";

    # Check the programmes haven't changed
    eq_or_diff $adv->load( programme => map { $_->{_uuid} } @prog ), [@orig],
     "programmes not changed";

    eq_or_diff [
      count_versions( $adv, programme => map { $_->{_uuid} } @prog )
     ],
     [5, 1, 5],
     "expected number of programme versions";

    eq_or_diff [count_versions( $adv, edit => map { $_->{uuid} } @edit )],
     [2, 2, 2],
     "expected number of edit versions";
  }

  # Create a new programme via an edit
  {
    my $new_prog = dclone $prog[0];

    $new_prog->{_uuid} = make_uuid();
    $new_prog->{title} = "New programme";
    $new_prog->{_key}  = 'new@prog';

    $_->{_uuid} = make_uuid() for @{ $new_prog->{related} };

    my $edit = {
      uuid     => make_uuid(),
      kind     => 'programme',
      object   => $new_prog->{_uuid},
      state    => 'pending',
      old_data => undef,
      new_data => $new_prog
    };

    $adv->save( edit => $edit );
    $edit->{state} = "accepted";
    $adv->save( edit => $edit );

    my $saved_prog = $adv->load( programme => $new_prog->{_uuid} );
    eq_or_diff $saved_prog->[0], $new_prog, "New programme created via edit";
  }
}

done_testing;

sub count_versions {
  my ( $ad, $kind, @ids ) = @_;
  return map { scalar @$_ } @{ $ad->versions( $kind, @ids ) };
}

sub schema {
  return Fenchurch::Adhocument::Schema->new(
    schema => test_data("schema.json") );
}

# vim:ts=2:sw=2:et:ft=perl

