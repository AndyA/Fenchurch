#!perl

use v5.10;

use autodie;
use strict;
use warnings;

use lib qw( t/lib );

use JSON ();
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
    schema        => schema(),
    db            => Fenchurch::Core::DB->new( dbh => database ),
    version_table => 'test_versions'
  );

  # Business logic: when an edit moves to 'accepted' apply it; when it
  # moves out of apply roll it back.

  $adv->on(
    version => sub {
      my $vers = shift;

      for my $ver (@$vers) {
        if ( $ver->{kind} eq "edit" ) {
          my $old_state = $ver->{old_data}{state} // "missing";
          my $new_state = $ver->{new_data}{state} // "deleted";

          if ( $old_state ne "accepted" && $new_state eq "accepted" ) {
           # Accepting
           #            say "Accepting ", JSON->new->pretty->canonical->encode($ver);
            my $edit = $ver->{new_data};
            $adv->save( { parents => [$ver->{uuid}] }, $edit->{kind},
              $edit->{data} );
          }
          elsif ( $old_state eq "accepted" && $new_state ne "accepted" ) {
            # Rejecting
            # say "Rejecting ", JSON->new->pretty->canonical->encode($ver);
            my $kind   = $ver->{new_data}{kind}   // $ver->{old_data}{kind};
            my $object = $ver->{new_data}{object} // $ver->{old_data}{object};
            my $versions = $adv->versions( $kind, $object );
            # say "Versions ", JSON->new->pretty->canonical->encode($versions);
          }
        }
      }

    }
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
    index      => 2,
    kind       => "member",
    last_name  => "Simmönds.",
    type       => "Unknown"
   };

  $prog[0]{title} = "The Föundatiöns öf Music";

  push @{ $prog[1]{contributors} },
   {code       => undef,
    first_name => "Gene",
    group      => "crew",
    index      => 4,
    kind       => "member",
    last_name  => "Simmöns.",
    type       => "Unknown"
   };

  $prog[1]{title} = "Kiss: The Wilderness Years";

  # An edit
  my @edit = (
    map {
      { uuid   => make_uuid(),
        kind   => 'programme',
        object => $_->{_uuid},
        state  => 'pending',
        data   => $_
      }
    } @prog
  );

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

  $_->{state} = 'rejected' for @edit;
  $adv->save( edit => @edit );
}

debug_versions();

done_testing;

# Some debug
sub debug_versions {
  my $vers = database->selectall_arrayref(
    join( " ",
      "SELECT `uuid`, `parent`, `kind`, `object`, `serial`, `sequence`, `when`",
      "  FROM `test_versions`",
      " ORDER BY `serial`" ),
    { Slice => {} }
  );
  my %by_uuid = ();
  for my $ver (@$vers) {
    $by_uuid{ $ver->{uuid} } = $ver;
  }
  my @root = ();
  for my $ver (@$vers) {
    if ( defined $ver->{parent} ) {
      my $parent = $by_uuid{ $ver->{parent} };
      push @{ $parent->{children} }, $ver;
    }
    else {
      push @root, $ver;
    }
  }
  diag "Version tree:";
  show_versions( 0, @root );
}

sub show_versions {
  my $indent = shift // 0;
  my $pad = "  " x $indent;
  for my $ver (@_) {
    diag $pad, join " ",
     @{$ver}{ 'kind', 'uuid', 'object', 'serial', 'sequence', 'when' };
    show_versions( $indent + 1, @{ $ver->{children} // [] } );
  }
}

sub schema {
  return Fenchurch::Adhocument::Schema->new(
    schema => {
      programme => {
        table  => 'test_programmes_v2',
        pkey   => '_uuid',
        plural => 'programmes',
      },
      contributor => {
        table    => 'test_contributors',
        child_of => { programme => '_parent' },
        order    => '+index',
        plural   => 'contributors',
      },
      related => {
        table    => 'test_related',
        pkey     => '_uuid',
        order    => '+index',
        child_of => { programme => '_parent' },
      },
      edit => {
        table => 'test_edit',
        pkey  => 'uuid',
        json  => ['data'],
      },
    }
  );
}

# vim:ts=2:sw=2:et:ft=perl

