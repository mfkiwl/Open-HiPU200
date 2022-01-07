#!/usr/bin/perl
#================================================================================
#   This file ramdom_lm.pl is used to generate random data for lmro/lmrw
#--------------------------------------------------------------------------------
#   USER    :   louwei
#   DATE    :   18 May 2020
#--------------------------------------------------------------------------------
#   Copyright 2020, All Right Reserved by XJTU ACG
#================================================================================
#   Description           : generate random file content for 512x64 memory
#   Generated File Format : @addr data (8 byte per line)
#   Usage                 : ./random_lm.pl outfile
#   Generated File        : outfile
#================================================================================

my $outfile = shift @ARGV;
my $data = 0;
my $line = "";
my $index = 0;
my $newindex = 0;

open( FILE, ">$outfile" ) || die "Error: can't open file '$outfile'\n$!";
foreach (0..511)
{
    $index = $index + 1;
    $line  = "";
    foreach (1..16)
    {
        $randdata = int(rand(16)); # generate a data [0,16)
        $data = sprintf("%1X", $randdata);
        $line = "$line"."$data";
    };
    $newindex = sprintf("%03X", $index);
    $newline = "@"."$newindex"."  "."$line";
    print FILE "$newline\n";
};
close FILE;
