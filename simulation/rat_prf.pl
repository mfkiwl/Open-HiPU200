#!/usr/bin/perl

$filename = "prf.hex";
$newfile  = "prf.info";
$index = 0;

open( FILE, "<$filename" ) || die "Error: can't open file '$filename'\n$!";
@content = <FILE>;
close FILE;

open( FILE, ">$newfile" ) || die "Error: can't open file '$filename'\n$!";
#print FILE "prf   value\n";
foreach $line (@content)
{   
    $index = sprintf("%2d", $index);
    $line = $index."    0x".$line;
    print FILE $line;
    $index = $index+1;
}
close FILE;

open( FILE, "<$newfile" ) || die "Error: can't open file '$filename'\n$!";
@prfcontent = <FILE>;
close FILE;

my $filename = "rat.dec";
my $newfile  = "rat.info";
my $index = 0;

my @gpr_name = ("zero", "ra", "sp",  "gp",  "tp", "t0", "t1", "t2", 
                "s0",   "s1", "a0",  "a1",  "a2", "a3", "a4", "a5",
                "a6",   "a7", "s2",  "s3",  "s4", "s5", "s6", "s7",
                "s8",   "s9", "s10", "s11", "t3", "t4", "t5", "t6");

open( FILE, "<$filename" ) || die "Error: can't open file '$filename'\n$!";
@content = <FILE>;
close FILE;

open( FILE, ">$newfile" ) || die "Error: can't open file '$newfile'\n$!";
print FILE "logic\t\tphysical\tvalue\n";

foreach $line (@content)
{   
    foreach $prfline (@prfcontent) {
        if ($prfline =~ /([0-9]+)\s+(0x[0-9a-fA-F]{8})/) {
            if ($1==$line) {
                chomp($line);
                $line = $line."\t\t\t".$2;
            } 
        } else {
            die "Error: prfline format is not correct!\n";
        }
    }
    $index = sprintf("%2d", $index);
    $line = $index."-".$gpr_name[$index]."\t\t".$line."\n";
    print FILE $line;
    $index = $index+1;
}
close FILE;

