#!perl

use v5.010;

use strict;
use warnings;

use Test::More;
use Test::Differences;
use MooseX::Test::Role;

use Fenchurch::Event::Emitter;
use Fenchurch::Event::Role::Emitter;

test_emitter( 'direct', Fenchurch::Event::Emitter->new );
test_emitter( 'role',
  consuming_object('Fenchurch::Event::Role::Emitter') );

sub test_emitter {
  my ( $desc, $ee ) = @_;
  my $stash = [];

  my $li_new_li    = make_listener( 'new_listener',    $stash );
  my $li_remove_li = make_listener( 'remove_listener', $stash );
  my $li_load      = make_listener( 'load',            $stash );
  my $li_load2     = make_listener( 'load2',           $stash );
  my $li_save      = make_listener( 'save',            $stash );
  my $li_delete    = make_listener( 'delete',          $stash );
  my $li_oneshot   = make_listener( 'oneshot',         $stash );

  $ee->on( 'new_listener', $li_new_li )
   ->on( 'remove_listener', $li_remove_li )->on( 'load', $li_load )
   ->on( 'save', $li_save )->on( 'delete', $li_delete )
   ->once( 'oneshot', $li_oneshot );

  eq_or_diff [splice @$stash],
   [{ args => ['new_listener', 'CODE', 0], handler => 'new_listener' },
    { args    => ['remove_listener', 'CODE', 0],
      handler => 'new_listener'
    },
    { args => ['load',    'CODE', 0], handler => 'new_listener' },
    { args => ['save',    'CODE', 0], handler => 'new_listener' },
    { args => ['delete',  'CODE', 0], handler => 'new_listener' },
    { args => ['oneshot', 'CODE', 1], handler => 'new_listener' }
   ],
   "$desc: events match 1";

  for ( 1 .. 3 ) {
    $ee->emit( 'load',    "load $_" );
    $ee->emit( 'oneshot', "oneshot $_" );
    $ee->emit( 'save',    "save $_" );
  }

  eq_or_diff [splice @$stash],
   [{ args => ['load 1'],    handler => 'load' },
    { args => ['oneshot 1'], handler => 'oneshot' },
    { args => ['oneshot', 'CODE', 1], handler => 'remove_listener' },
    { args => ['save 1'], handler => 'save' },
    { args => ['load 2'], handler => 'load' },
    { args => ['save 2'], handler => 'save' },
    { args => ['load 3'], handler => 'load' },
    { args => ['save 3'], handler => 'save' }
   ],
   "$desc: events match 2";

  $ee->remove_listener( 'new_listener',    $li_new_li );
  $ee->remove_listener( 'remove_listener', $li_remove_li );

  eq_or_diff [splice @$stash], [
    { args    => ['new_listener', 'CODE', 0],
      handler => 'remove_listener'
    },
    { args    => ['remove_listener', 'CODE', 0],
      handler => 'remove_listener'
    }
   ],
   "$desc: events match 3";

  my $li_load_bar = make_listener( 'load.bar', $stash );
  my $li_load_foo = make_listener( 'load.foo', $stash );
  my $li_save_baz = make_listener( 'save.baz', $stash );
  my $li_save_foo = make_listener( 'save.foo', $stash );

  $ee->on( 'load.bar', $li_load_bar );
  $ee->on( 'load.foo', $li_load_foo );
  $ee->on( 'save.baz', $li_save_baz );
  $ee->on( 'save.foo', $li_save_foo );

  $ee->emit( 'load', 'load 4' );
  $ee->emit( 'save', 'save 4' );

  eq_or_diff [splice @$stash],
   [{ args => ['load 4'], handler => 'load' },
    { args => ['load 4'], handler => 'load.bar' },
    { args => ['load 4'], handler => 'load.foo' },
    { args => ['save 4'], handler => 'save' },
    { args => ['save 4'], handler => 'save.baz' },
    { args => ['save 4'], handler => 'save.foo' }
   ],
   "$desc: events match 4";

  $ee->off('load.baz');    # doesn't exist
  $ee->emit( 'load', 'load 5' );

  eq_or_diff [splice @$stash],
   [{ args => ['load 5'], handler => 'load' },
    { args => ['load 5'], handler => 'load.bar' },
    { args => ['load 5'], handler => 'load.foo' }
   ],
   "$desc: events match 5";

  $ee->off('.foo');
  $ee->emit( 'load', 'load 6' );
  $ee->emit( 'save', 'save 6' );

  eq_or_diff [splice @$stash],
   [{ args => ['load 6'], handler => 'load' },
    { args => ['load 6'], handler => 'load.bar' },
    { args => ['save 6'], handler => 'save' },
    { args => ['save 6'], handler => 'save.baz' }
   ],
   "$desc: events match 6";

  my $li_foo_bar_baz = make_listener( 'foo.bar.baz', $stash );
  my $li_foo_bar_foo = make_listener( 'foo.bar.foo', $stash );
  my $li_foo_baz_bar = make_listener( 'foo.baz.bar', $stash );
  my $li_foo_baz_foo = make_listener( 'foo.baz.foo', $stash );
  my $li_foo_foo_bar = make_listener( 'foo.foo.bar', $stash );
  my $li_foo_foo_baz = make_listener( 'foo.foo.baz', $stash );
  my $li_bar_bar_baz = make_listener( 'bar.bar.baz', $stash );
  my $li_bar_bar_foo = make_listener( 'bar.bar.foo', $stash );
  my $li_bar_baz_bar = make_listener( 'bar.baz.bar', $stash );
  my $li_bar_baz_foo = make_listener( 'bar.baz.foo', $stash );
  my $li_bar_foo_bar = make_listener( 'bar.foo.bar', $stash );
  my $li_bar_foo_baz = make_listener( 'bar.foo.baz', $stash );

  $ee->on( 'foo.bar.baz', $li_foo_bar_baz );
  $ee->on( 'foo.bar.foo', $li_foo_bar_foo );
  $ee->on( 'foo.baz.bar', $li_foo_baz_bar );
  $ee->on( 'foo.baz.foo', $li_foo_baz_foo );
  $ee->on( 'foo.foo.bar', $li_foo_foo_bar );
  $ee->on( 'foo.foo.baz', $li_foo_foo_baz );
  $ee->on( 'bar.bar.baz', $li_bar_bar_baz );
  $ee->on( 'bar.bar.foo', $li_bar_bar_foo );
  $ee->on( 'bar.baz.bar', $li_bar_baz_bar );
  $ee->on( 'bar.baz.foo', $li_bar_baz_foo );
  $ee->on( 'bar.foo.bar', $li_bar_foo_bar );
  $ee->on( 'bar.foo.baz', $li_bar_foo_baz );

  $ee->emit( 'foo', 'foo 1' );
  $ee->emit( 'bar', 'bar 1' );

  eq_or_diff [splice @$stash],
   [{ args => ['foo 1'], handler => 'foo.bar.baz' },
    { args => ['foo 1'], handler => 'foo.bar.foo' },
    { args => ['foo 1'], handler => 'foo.baz.bar' },
    { args => ['foo 1'], handler => 'foo.baz.foo' },
    { args => ['foo 1'], handler => 'foo.foo.bar' },
    { args => ['foo 1'], handler => 'foo.foo.baz' },
    { args => ['bar 1'], handler => 'bar.bar.baz' },
    { args => ['bar 1'], handler => 'bar.bar.foo' },
    { args => ['bar 1'], handler => 'bar.baz.bar' },
    { args => ['bar 1'], handler => 'bar.baz.foo' },
    { args => ['bar 1'], handler => 'bar.foo.bar' },
    { args => ['bar 1'], handler => 'bar.foo.baz' }
   ],
   "$desc: events match 7";

  $ee->off('foo.baz');

  $ee->emit( 'foo', 'foo 2' );
  $ee->emit( 'bar', 'bar 2' );

  eq_or_diff [splice @$stash],
   [{ args => ['foo 2'], handler => 'foo.bar.foo' },
    { args => ['foo 2'], handler => 'foo.foo.bar' },
    { args => ['bar 2'], handler => 'bar.bar.baz' },
    { args => ['bar 2'], handler => 'bar.bar.foo' },
    { args => ['bar 2'], handler => 'bar.baz.bar' },
    { args => ['bar 2'], handler => 'bar.baz.foo' },
    { args => ['bar 2'], handler => 'bar.foo.bar' },
    { args => ['bar 2'], handler => 'bar.foo.baz' }
   ],
   "$desc: events match 8";

  $ee->off( 'bar', $li_bar_foo_bar );

  $ee->emit( 'foo', 'foo 2' );
  $ee->emit( 'bar', 'bar 2' );

  eq_or_diff [splice @$stash],
   [{ args => ['foo 2'], handler => 'foo.bar.foo' },
    { args => ['foo 2'], handler => 'foo.foo.bar' },
    { args => ['bar 2'], handler => 'bar.bar.baz' },
    { args => ['bar 2'], handler => 'bar.bar.foo' },
    { args => ['bar 2'], handler => 'bar.baz.bar' },
    { args => ['bar 2'], handler => 'bar.baz.foo' },
    { args => ['bar 2'], handler => 'bar.foo.baz' }
   ],
   "$desc: events match 9";

  $ee->off('.baz.bar');

  $ee->emit( 'foo', 'foo 2' );
  $ee->emit( 'bar', 'bar 2' );

  eq_or_diff [splice @$stash], [], "$desc: events match 10";
  #  make_test($stash);

}

done_testing();

sub make_test {
  my $stash = shift;
  return unless @$stash;
  use Data::Dumper;

  my $dd
   = Data::Dumper->new( [$stash], ['stash'] )->Quotekeys(0)->Sortkeys(1)
   ->Terse(1);

  ( my $dump = $dd->Dump ) =~ s/\s+/ /g;

  say 'eq_or_diff [splice @$stash], ', $dump, ', "$desc: events match 1";';

}

sub make_listener {
  my ( $name, $stash ) = @_;
  return sub {
    push @$stash,
     {handler => $name,
      args    => [map { ref $_ && 'CODE' eq ref $_ ? 'CODE' : $_ } @_],
     };
  };
}

# vim:ts=2:sw=2:et:ft=perl

