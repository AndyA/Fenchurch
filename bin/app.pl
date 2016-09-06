#!/usr/bin/env perl
use Dancer;

use FindBin;

use lib glob "$FindBin::Bin/../../*/lib";

use Lintilla::Syncotron::Site;
dance;
