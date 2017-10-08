#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Dancer2;
#use inventory;
use rollcall;

#inventory->to_app;
rollcall->to_app;
start;
