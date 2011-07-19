#!/usr/bin/perl -w
use warnings;
use strict;
use Storable;
use Data::Dumper;
use Devel::Size qw(size total_size);
use lib "../filters";
use dnaCode;
use dnaPack;

my $seqLen   = 32;
my $fileName = $ARGV[0];

die "FILE $fileName WAS NOT FOUND\n"        if ( ! -f $fileName );
die "FILE $fileName NOT WORDCOUNT BINARY\n" if ( ! $fileName =~ /\.wb$/);

my $fileSize = -s $fileName;

print "IMPORTING $fileName (",$fileSize," bytes - ",&byte2Mb($fileSize)," Mb)\n";
my $outName = $fileName;
$outName =~ s/.wb/.wc/;

open IN, "<$fileName" or die "COULD NOT OPEN $fileName";
open OUT, ">$outName" or die "COULD NOT OPEN $outName";

binmode IN;
	
my ($data, $n);
my $shortLen = ($seqLen/4);
my $countExport = 0;	
while (($n = read IN, $data, $shortLen) != 0)
{
	
	print OUT &dnaPack::unPackDNA($data, $seqLen), "\n";
	$countExport++;

	#$outHash->[ord(substr($data,0,1))]{substr($data,1)}++;
	#my $frag   = &dnaCode::digit2dna($frag80);
	#my $frag8  = &dnaPack::packDNA($frag);
	#my $frag08 = &dnaPack::unPackDNA($data, $seqLen);
	#print "FRAG80 $frag80 FRAG $frag FRAG8 $frag8 FRAG08 $frag08\n";
	#print "FRAG $data (",length($data),") FRAG08 $frag08 (",length($frag08),")\n";
	#die "CONVERSION ERROR\n" if ($frag08 ne $frag);
}
	
close IN;
close OUT;
my $outFileSize = -s $outName;

print "$countExport SEQUENCES EXPORTED (",$outFileSize," bytes - ",&byte2Mb($outFileSize)," Mb)\n";


sub byte2Mb
{
    my $in = $_[0];
    my $mb = (($in / 1024) / 1024);
    return sprintf("%.1f",$mb);
}

1;