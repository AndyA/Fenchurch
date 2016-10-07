#!perl

use v5.10;

use strict;
use warnings;

use lib qw( t/lib );

use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Syncotron::MessageQueue;

preflight;

empty 'test_queue';

my $db = Fenchurch::Core::DB->new( dbh => database );

for my $vary ( 'role', 'from', 'to' ) {
  test_queue( $db, $vary );
}

for my $vary ( 'role', 'from', 'to' ) {
  my ( $mq1, $mq2 ) = make_mq_pair( $db, $vary );
  is $mq1->available, 1, "Checking $vary: One item on queue 1";
  is $mq2->available, 1, "Checking $vary: One item on queue 2";
}

sub test_queue {
  my ( $db, $vary ) = @_;

  my $pfx = "Varying $vary";

  {
    my ( $mq1, $mq2 ) = make_mq_pair( $db, $vary );

    is $mq1->available, 0, "$pfx: Queue 1 initially empty";
    is $mq2->available, 0, "$pfx: Queue 2 initially empty";

    $mq1->send( { index => 1, name => "First" },
      { index => 2, name => "Second" } );

    $mq2->send( { index => 3, name => "First" } );

    $mq1->send( { index => 4, name => "Third" } );

    is $mq1->available, 3, "$pfx: Three message on queue 1";
    is $mq2->available, 1, "$pfx: One message on queue 2";
  }

  {
    my ( $mq1, $mq2 ) = make_mq_pair( $db, $vary );
    is $mq1->available, 3, "$pfx: Three messages still on queue 1";
    is $mq2->available, 1, "$pfx: One message still on queue 2";

    eq_or_diff [$mq1->peek(1)], [{ index => 1, name => "First" }],
     "$pfx: Peek got first message";

    eq_or_diff [$mq1->peek(2)],
     [{ index => 1, name => "First" }, { index => 2, name => "Second" }],
     "$pfx: Peek got first two messages";

    eq_or_diff [$mq1->peek],
     [{ index => 1, name => "First" },
      { index => 2, name => "Second" },
      { index => 4, name => "Third" }
     ],
     "$pfx: Peek got all three messages";

    is $mq1->available, 3, "$pfx: Three messages still on queue 1";

    eq_or_diff [$mq1->take(1)], [{ index => 1, name => "First" }],
     "$pfx: Take got first message";

    is $mq1->available, 2, "$pfx: Two messages still on queue 1";

    eq_or_diff [$mq1->take],
     [{ index => 2, name => "Second" }, { index => 4, name => "Third" }],
     "$pfx: Take got remaining two messages";

    # Push some more stuff on mq2
    $mq2->send( { index => 5, name => "Second" } );
  }

  {
    my ( $mq1, $mq2 ) = make_mq_pair( $db, $vary );
    is $mq1->available, 0, "$pfx: Queue 1 empty";
    is $mq2->available, 2, "$pfx: Two messages on queue 2";

    {
      my @got  = ();
      my $done = 0;
      $mq1->with_messages( sub { $done++; push @got, @_ } );
      is $done, 1, "$pfx: One callback";
      eq_or_diff [@got], [], "$pfx: No messages";
    }

    {
      my @got  = ();
      my $done = 0;
      $mq2->with_messages( sub { $done++; push @got, @_ } );
      is $done, 1, "$pfx: One callback";
      eq_or_diff [@got],
       [{ index => 3, name => "First" }, { index => 5, name => "Second" }],
       "$pfx: Two messages";
      is $mq2->available, 0, "$pfx: Queue 2 empty";
    }

    {
      $mq2->send( { index => 6, name => "Third" } );
      $mq2->send( { index => 7, name => "Fourth" } );

      eval {
        $mq2->with_messages( sub { die } );
      };

      ok !!$@, "$pfx: Error thrown";
      eq_or_diff [$mq2->take],
       [{ index => 6, name => "Third" }, { index => 7, name => "Fourth" }],
       "$pfx: Messages left on queue";
    }

    $_->send( { index => 99, name => "Done" } ) for $mq1, $mq2;
  }
}

done_testing;

sub make_mq_pair {
  my ( $db, $vary ) = @_;
  my %args = (
    role => $vary . 'RoleA',
    from => $vary . 'FromA',
    to   => $vary . 'ToA'
  );
  my $mq1 = make_mq( $db, %args );
  $args{$vary}++;
  my $mq2 = make_mq( $db, %args );
  return ( $mq1, $mq2 );
}

sub make_mq {
  my ( $db, %args ) = @_;

  return Fenchurch::Syncotron::MessageQueue->new(
    %args,
    db    => $db,
    table => 'test_queue'
  );
}

# vim:ts=2:sw=2:et:ft=perl

