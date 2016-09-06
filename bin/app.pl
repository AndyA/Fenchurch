#!/usr/bin/env perl
use Dancer;

use FindBin;

use lib glob "$FindBin::Bin/../../*/lib";

use Fenchurch::Syncotron::Site;
dance;
