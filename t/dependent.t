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
      my $json = $adv->_json;    # well...
      for my $ver (@$vers) {
        if ( $ver->{kind} eq "edit" ) {
          my $old_state = $ver->{old_data}{state} // "missing";
          my $new_state = $ver->{new_data}{state} // "deleted";

          if ( $old_state ne "accepted" && $new_state eq "accepted" ) {
            my $edit = $ver->{new_data};
            $adv->save( $edit->{kind}, $edit->{data} );
          }
          elsif ( $old_state eq "accepted" && $new_state ne "accepted" ) {
           #            say "Rejecting ", JSON->new->pretty->canonical->encode($ver);
            my $kind   = $ver->{new_data}{kind}   // $ver->{old_data}{kind};
            my $object = $ver->{new_data}{object} // $ver->{old_data}{object};
            my $versions = $adv->versions( $kind, $object );
       #            say "Versions ", JSON->new->pretty->canonical->encode($versions);
          }
        }
      }

    }
  );

  my $prog_edit = dclone $programmes->[0];
  my $prog_orig = dclone $prog_edit;

  # Make some changes
  push @{ $prog_edit->{contributors} },
   {code       => undef,
    first_name => "Kathryn",
    group      => "crew",
    index      => 2,
    kind       => "member",
    last_name  => "Simmönds.",
    type       => "Unknown"
   };

  $prog_edit->{title} = "The Föundatiöns öf Music";

  # An edit
  my $edit = {
    uuid   => make_uuid(),
    kind   => 'programme',
    object => $prog_edit->{_uuid},
    state  => 'pending',
    data   => $prog_edit
  };

  $adv->save( edit => $edit );

  eq_or_diff $adv->load( edit => $edit->{uuid} ), [$edit], "edit saved OK";

  $edit->{state} = 'review';
  $adv->save( edit => $edit );

  $edit->{state} = 'accepted';
  $adv->save( edit => $edit );

  # Check programme
  eq_or_diff $adv->load( programme => $prog_edit->{_uuid} ), [$prog_edit],
   "programme edited OK";

  $edit->{state} = "rejected";
  $adv->save( edit => $edit );
}

done_testing;

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

