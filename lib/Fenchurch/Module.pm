package Fenchurch::Module;

use 5.24.0;
use autodie;
use strict;
use warnings;
use feature ();
use utf8::all;
use Carp;

use Import::Into;

sub import {
  my ($class) = @_;

  my $caller = caller;

  autodie->import;
  warnings->import;
  warnings->unimport('experimental::signatures');
  strict->import;
  feature->import(qw/signatures :5.24/);
  utf8::all->import;
  Carp->import::into( $caller, qw(carp croak) );
}

sub unimport {
  autodie->unimport;
  warnings->unimport;
  strict->unimport;
  feature->unimport;
  utf8::all->unimport;
  Carp->unimport;
}

1;
