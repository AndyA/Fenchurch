#!perl

use lib qw( t/lib );

use JSON;
use Test::Differences;
use Test::More;

use Fenchurch::Syncotron::Controller;
use Fenchurch::Syncotron::Despatcher;

my $de = Fenchurch::Syncotron::Despatcher->new;

$de->on(
  ping => sub {
    my ( $ev, $ctl ) = @_;
    $ctl->reply( { type => 'pong' } );
  }
);

my $ctl = Fenchurch::Syncotron::Controller->new( despatcher => $de );

{
  my $got = $ctl->handle_raw_message( [{ type => 'ping' }] );
  eq_or_diff $got, [{ type => 'pong' }], "sent ping, got pong";
}

{
  my $got = $ctl->handle_raw_message( [] );
  eq_or_diff $got, [], "sent nothing, got nothing";
}

{
  my $js  = JSON->new;
  my $got = $js->decode(
    $ctl->handle_message( $js->encode( [{ type => 'ping' }] ) ) );
  eq_or_diff $got, [{ type => 'pong' }], "sent ping, got pong (JSON)";
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

