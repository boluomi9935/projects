#!/usr/bin/perl -w
use warnings;
use strict;

use lib "./filters";
use dnaCodeOO;

my $inFile  = $ARGV[0];
my $outFile = "$inFile.conv";
my $dnaCode = dnaCodeOO->new();

open FILE, "<$inFile" or die "COULD NOT OPEN $inFile: $!";
open OUT, ">$outFile" or die "COULD NOT OPEN $outFile: $!";

while (my $line = <FILE>)
{
	chomp $line;
	
	if ($line =~ /(.*)\t(.*)/)
	{
		my $frag = $1;
		my $valu = $2;
		
		my $conv = $dnaCode->digit2dna($frag);
		print OUT $conv, "\t", $valu, "\n";
	}
}

close OUT;
close FILE;
