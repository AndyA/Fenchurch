#!perl

use strict;
use warnings;
use Test::More;
use Test::Differences;

use Fenchurch::Syncotron::Despatcher;

{
  my $de = Fenchurch::Syncotron::Despatcher->new;

  my @log = ();

  $de->on(
    'foo.bar' => sub {
      my $ev = shift;
      push @log, { h => 'foo.bar', t => $ev->{type} };
    }
   )->on(
    'foo.baz' => sub {
      my $ev = shift;
      push @log, { h => 'foo.baz', t => $ev->{type} };
    }
   )->on(
    'foo.*' => sub {
      my $ev = shift;
      push @log, { h => 'foo.*', t => $ev->{type} };
    }
   )->on(
    'foo.**' => sub {
      my $ev = shift;
      push @log, { h => 'foo.**', t => $ev->{type} };
    }
   )->on(
    'foo.*.x' => sub {
      my $ev = shift;
      push @log, { h => 'foo.*.x', t => $ev->{type} };
    }
   )->on(
    'foo.**.x' => sub {
      my $ev = shift;
      push @log, { h => 'foo.**.x', t => $ev->{type} };
    }
   )->on(
    qr{burp} => sub {
      my $ev = shift;
      push @log, { h => '/burp/', t => $ev->{type} };
    }
   )->on(
    [qr{pies}, 'svc.*.boff'] => sub {
      my $ev = shift;
      push @log, { h => '[multi]', t => $ev->{type} };
    }
   );

  is $de->despatch( { type => 'foo.bar' } ), 3,
   'foo.bar: 3 handlers called';
  is $de->despatch( { type => 'foo.baz' } ), 3,
   'foo.baz: 3 handlers called';
  is $de->despatch( { type => 'foo.burp' } ), 3,
   'foo.baz: 3 handlers called';
  is $de->despatch( { type => 'foo.pies.burp.x' } ), 4,
   'foo.pies.burp.x: 4 handlers called';
  is $de->despatch( { type => 'svc.burp.boff' } ), 2,
   'svc.burp.boff: 2 handlers called';
  is $de->despatch( { type => 'svc.pies.boff' } ), 1,
   'svc.pies.boff: 1 handlers called';

  eq_or_diff \@log,
   [{ h => 'foo.bar',  t => 'foo.bar' },
    { h => 'foo.*',    t => 'foo.bar' },
    { h => 'foo.**',   t => 'foo.bar' },
    { h => 'foo.baz',  t => 'foo.baz' },
    { h => 'foo.*',    t => 'foo.baz' },
    { h => 'foo.**',   t => 'foo.baz' },
    { h => 'foo.*',    t => 'foo.burp' },
    { h => 'foo.**',   t => 'foo.burp' },
    { h => '/burp/',   t => 'foo.burp' },
    { h => 'foo.**',   t => 'foo.pies.burp.x' },
    { h => 'foo.**.x', t => 'foo.pies.burp.x' },
    { h => '/burp/',   t => 'foo.pies.burp.x' },
    { h => '[multi]',  t => 'foo.pies.burp.x' },
    { h => '/burp/',   t => 'svc.burp.boff' },
    { h => '[multi]',  t => 'svc.burp.boff' },
    { h => '[multi]',  t => 'svc.pies.boff' },
   ],
   'call log';
}

done_testing();

# vim:ts=2:sw=2:et:ft=perl

