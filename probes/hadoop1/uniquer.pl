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

my $outId    = $ARGV[0];
my $inFolder = $ARGV[1];
my @inFiles  = @ARGV[2 .. (@ARGV-1)];
my %inSizes;
my %inSizesBkg;

if ( ! defined $outId ) { die "OUTPUT ID NOT DEFINED"; };
if ( ! -d $inFolder )   { die "INPUT FOLDER $inFolder DOESNT EXISTS"; };
if ( ! @inFiles )       { die "NO INPUT FILES DEFINED"; };
if ( @inFiles == 1 )    { die "ONLY 1 FILE DEFINED"; };
if ( -f "$outId.shares.wc" )   { die "OUTPUT ID FILE $outId.shared.wc EXISTS"; };
if ( -f "$outId.unique.wc" )   { die "OUTPUT ID FILE $outId.unique.wc EXISTS"; };

@inFiles  = &listInFiles(\@inFiles);
my @inBkg = &listInBkg($inFolder, \@inFiles);

my $totalOrgs = @inFiles;
my $totalBkg  = @inBkg;


my $repeated = &makeSharedHash(\@inFiles, $totalOrgs);
my $unique   = &makeUniqueHash($repeated, \@inBkg, $totalOrgs);

&saveWcDup("$outId.shared", $repeated, $totalOrgs);
&saveWcDup("$outId.unique", $unique,   $totalOrgs);





sub makeUniqueHash
{
	my $original  = $_[0];
	my $copy      = {};
	%{$copy}      = %{$original};
	my $bkgFiles  = $_[1];
	my $threshold = $_[2];
	my $fileCount = 0;
	
	print "MAKING SHARED HASH\n";
	for (my $i = 0; $i < @{$bkgFiles}; $i++)
	{
		my $fileName = $bkgFiles->[$i];
		printf "\tIMPORTING %15s ( %012d bytes - %04d.1f Mb )\n", $fileName, $inSizesBkg{$fileName}, &byte2Mb($inSizesBkg{$fileName});
		open IN, "<$fileName" or die "COULD NOT OPEN $fileName";
		binmode IN;
		
		my ($data, $n);
		my $shortLen     = ($seqLen/4);
		my $shortFragLen = ($fragLen/4);
		my $leftLen      = ($shortLen - $fragLen)/2;
		
		while (($n = read IN, $data, $shortLen) != 0)
		{
			my $lData = $data;
			if ($shortLen ne $shortFragLen)
			{
				$lData = substr($data, $leftLen, $shortFragLen);
			}
			if ( exists $copy->{$lData} ) { $copy->{$lData} = 0 };
		}
		
		$fileCount++;
		close IN;
	}
	
	my $uniquely = 0;

	while ((my $key, my $value ) = each (%{$copy}))
	{
		if ( $copy->{$key} )
		{
			$uniquely++;
		}
		else
		{
			delete($copy->{$key});
		}
	}
	
	print "\t$fileCount FILES ANALYZED; ", scalar (keys %{$copy}), " UNIQUE SEQS / ", scalar (keys %{$original}),"; $uniquely UNIQUE\n";
	return $copy;
}




sub makeSharedHash
{
	my $array     = $_[0];
	my $threshold = $_[1];
	my $fileCount = 0;
	
	my $outHash;
	my $repeatHash;
	print "MAKING SHARED HASH\n";
	for (my $i = 0; $i < @{$array}; $i++)
	{
		my $fileName = $array->[$i];
		printf "\tIMPORTING %15s ( %012d bytes - %04d.1f Mb )\n", $fileName, $inSizes{$fileName}, &byte2Mb($inSizes{$fileName});
		open IN, "<$fileName" or die "COULD NOT OPEN $fileName";
		binmode IN;
		
		my ($data, $n);
		my $shortLen     = ($seqLen/4);
		my $shortFragLen = ($fragLen/4);
		my $leftLen      = ($shortLen - $fragLen)/2;
		
		while (($n = read IN, $data, $shortLen) != 0)
		{
			my $lData = $data;
			if ($shortLen ne $shortFragLen)
			{
				$lData = substr($data, $leftLen, $shortFragLen);
			}
			
			if ( $fileCount )
			{
				if ( exists $outHash->{$lData} )
				{
					$repeatHash->{$lData}++;
				}
			}
			else
			{
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
	
	my $shared = 0;
	
	while ((my $key, my $value ) = each (%{$repeatHash}))
	{
		if ($repeatHash->{$key} == ($threshold - 1))
		{
			$shared++;
		}
		else
		{
			delete($repeatHash->{$key});
		}
	}
	
	print "\t$fileCount FILES ANALYZED; ", scalar (keys %{$repeatHash}), " REPEATED SEQS; $shared\n";
	return $repeatHash;
}




sub listInFiles
{
	my $inInFiles = $_[0];
	
	for (my $i = 0; $i < @{$inInFiles}; $i++)
	{
		my $fileName = "$inInFiles->[$i].wc";
		if ( ! -f "$fileName" )
		{
			die "$fileName DOESNT EXISTS" ;
		}
	
		$inSizes{$fileName} = -s $fileName;
	}


	my @sorted = sort { $inSizes{$a} <=> $inSizes{$b} } keys %inSizes;
	
	foreach my $file (@sorted)
	{
		print "\tINPUT $file\n";
	}
	
	return @sorted;
}




sub listInBkg
{
	my $inInFolder = $_[0];
	my $inInFiles  = $_[1];
	my %inInFiles;
	
	foreach my $file (@{$inInFiles})
	{
		$inInFiles{$file} = 1;
	}
	
	opendir (DIR, "$inInFolder") or die $!;
	my @inBackground = grep /\.wc$/, readdir(DIR);
	closedir DIR;
	$| = 1;
	
	if ( ! @inBackground ) { die "NO WC FILES FOUND IN $inFolder DIRECTORY"};
	
	for (my $i = 0; $i < @inBackground; $i++)
	{
		my $fileName = "$inBackground[$i]";
		
		next if ( defined $inInFiles{$fileName} );
		
		if ( ! -f "$fileName" )
		{
			die "$fileName DOESNT EXISTS" ;
		}
	
		$inSizesBkg{$fileName} = -s $fileName;
	}
	
	my @sortedBkg = sort { $inSizesBkg{$a} <=> $inSizesBkg{$b} } keys %inSizesBkg;

	foreach my $file (@sortedBkg)
	{
		print "\tBACKG $file\n";
	}
	
	return @sortedBkg;
}




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