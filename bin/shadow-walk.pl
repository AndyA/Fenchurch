#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer ':script';
use Dancer::Plugin::Database;
use JSON();

use Fenchurch::DB::Genome::Shadow;

my $shadow = Fenchurch::DB::Genome::Shadow->new( dbh => database );
my $json = JSON->new->pretty->canonical;

my $changes = $shadow->_load_changes( 1, 200 );
say $json->encode($changes)
