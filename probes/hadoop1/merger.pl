#!/usr/bin/perl -w
use warnings;
use strict;
use Storable;
use Data::Dumper;
use Devel::Size qw(size total_size);
use lib "../filters";
use dnaCode;
use dnaPack;

my $seqLen  = 32;
my $fragLen = 32;
my $unique;

my $outId   = $ARGV[0];
my @inFiles = @ARGV[1 .. (@ARGV-1)];
my %inSizes;

if ( ! defined $outId ) { die "OUTPUT ID NOT DEFINED"; };
if ( ! @inFiles )       { die "NO INPUT FILES DEFINED"; };
if ( @inFiles == 1 )    { die "ONLY 1 FILE DEFINED"; };
if ( -f "$outId.wb" )   { die "OUTPUT ID FILE $outId.wb EXISTS"; };


for (my $i = 0; $i < @inFiles; $i++)
{
	my $fileName = "$inFiles[$i].wb";
	if ( ! -f "$fileName" )
	{
		die "$fileName DOESNT EXISTS" ;
	}

	$inSizes{$fileName} = -s $fileName;
}

my @sorted = sort { $inSizes{$a} <=> $inSizes{$b} } keys %inSizes; 

my $totalOrgs = @inFiles;

my $outHash;
my $repeatHash;
my $fileCount = 0;

for (my $i = 0; $i < @sorted; $i++)
{
	my $fileName = $sorted[$i];
	print "IMPORTING $fileName (",$inSizes{$fileName}," bytes - ",&byte2Mb($inSizes{$fileName})," Mb)\n";
	open IN, "<$fileName" or die "COULD NOT OPEN $fileName";
	binmode IN;
	
	my ($data, $n);
	my $shortLen     = ($seqLen/4);
	my $shortFragLen = ($fragLen/4);
	my $leftLen      = ($shortLen - $fragLen)/2;
	
	while (($n = read IN, $data, $shortLen) != 0)
	{
		if ( $fileCount )
		{
			my $lData = substr($data, $leftLen, $shortFragLen);
			if ( exists $outHash->{$lData} )
			{
				$repeatHash->{$lData}++;
			}
		}
		else
		{
			my $lData = substr($data, $leftLen, $shortFragLen);
			$outHash->{$lData}++;
		}
		#$outHash->[ord(substr($data,0,1))]{substr($data,1)}++;
		#my $frag   = &dnaCode::digit2dna($frag80);
		#my $frag8  = &dnaPack::packDNA($frag);
		#my $frag08 = &dnaPack::unPackDNA($data, $seqLen);
		#print "FRAG80 $frag80 FRAG $frag FRAG8 $frag8 FRAG08 $frag08\n";
		#print "FRAG $data (",length($data),") FRAG08 $frag08 (",length($frag08),")\n";
		#die "CONVERSION ERROR\n" if ($frag08 ne $frag);
	}
	
	$fileCount++;
	close IN;
}

&saveWcDup($outId, $repeatHash, $totalOrgs);

sub saveWcDup
{
	my $inputTaxonId = $_[0];
	my $wcHash       = $_[1];
	my $threshold    = $_[2];
	
	my $totalK   = keys %{$wcHash};
	my $exported = 0;
	print "\tSAVING WORD COUNT. $totalK WORDS FOUND... ";
	
	open WC, ">$inputTaxonId.wb" or die;
	binmode WC;
	
	while ((my $word, my $count) = each (%{$wcHash}))
	{
		if ($count == ($threshold - 1))
		{
			print WC $word;
			$exported++;
		}
	}

	close WC;
	
	rename("$inputTaxonId.wb","$inputTaxonId.wc") or die "COULD NOT RENAME TEMP FILE $inputTaxonId.wb: $!";
	print "\tDONE ($exported EXPORTED)\n";
}

sub byte2Mb
{
    my $in = $_[0];
    my $mb = (($in / 1024) / 1024);
    return sprintf("%.1f",$mb);
}

1;


