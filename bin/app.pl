#!/usr/bin/env perl

use FindBin '$RealBin';

use lib "$FindBin::Bin/../../Fenchurch/lib";

use Dancer;
use Fenchurch::Wiki;

dance;
