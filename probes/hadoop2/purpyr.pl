#!/usr/bin/perl -w
use strict;
use lib "./filters";


#my $inFile = $ARGV[0];
#die "NO INPUT FILE DEFINED" if ( ! defined $inFile );
#die "FILE $inFile DOESNT EXISTS" if ( ! -f $inFile );

my $totalLines = 0;
#open INFILE,   "<$inFile"   or die "COULD NOT OPEN $inFile   : $!";
#my $binCount = '0'x 1_073_741_824;
my $binCount = "0\0";
#$binCount = $binCount x 1_073_741_824; #2_147_438_648;
$| = 1;
print length($binCount);
#sleep 15;
my $lastSeq = "";
my $lastSeqBin = "";
my $lastSeqDec = "";
#while (my $line = <INFILE>)
while (my $line = <STDIN>)
{
	$totalLines++;
	chomp $line;
	(my $orig, my $pos) = split("\t", $line);


	my $origBin = $orig;
	   $origBin =~ tr/ACGT/0110/;
	my $origDec = &bin2dec($origBin);

	my $rc      = $orig;
	   $rc      = reverse($rc);
	my $rcBin   = $rc;
	   $rcBin   =~ tr/ACGT/0110/;
	my $rcDec   = &bin2dec($rcBin);

	if ($origDec < $rcDec)
	{
		print sprintf("%x", 0 x (10 - length($origDec)). $origDec), "\t", $pos, "\n";
	}
	else
	{
		print sprintf("%x", 0 x (10 - length($rcDec)). $rcDec), "\t", $pos, "\n";
	}


	#my $origBin = $orig;
	#   $origBin =~ tr/ACGT/0110/;
	#my $origDec = &bin2dec($origBin);
	#
	#my $reverse = reverse($orig);
	#my $revBin  = $reverse;
	#   $revBin  =~ tr/ACGT/0110/;
	#my $revDec  = &bin2dec($revBin);
	#
	#my $rc      = $orig;
	#   $rc      = reverse($rc);
	#   $rc      =~ tr/ACGT/TGCA/;
	#my $rcBin   = $rc;
	#   $rcBin   =~ tr/ACGT/0110/;
	#my $rcDec   = &bin2dec($rcBin);
	#
	#my $comp    = $orig;
	#   $comp    =~ tr/ACGT/TGCA/;
	#my $compBin = $comp;
	#   $compBin =~ tr/ACGT/0110/;
	#my $compDec = &bin2dec($compBin);
	#
	#my $negDec  = ! $origDec;
	#my $negBin  = &dec2bin($negDec);
	#
	##$binCount[$transDec]++;
	#
	#print "FWD  : ", $orig    , " (",length($orig)   , ") -> ", $origBin , " (", length($origBin) , ") => ", $origDec , " (", length($origDec) , ") == ", &dec2bin($origDec) , " (",length(&dec2bin($origDec)) , ")\n";
	##print "COMP : ", $comp    , " (",length($comp)   , ") -> ", $compBin , " (", length($compBin) , ") => ", $compDec , " (", length($compDec) , ") == ", &dec2bin($compDec) , " (",length(&dec2bin($compDec)) , ")\n";
	#print "REV  : ", $reverse , " (",length($reverse), ") -> ", $revBin  , " (", length($revBin)  , ") => ", $revDec  , " (", length($revDec)  , ") == ", &dec2bin($revDec)  , " (",length(&dec2bin($revDec))  , ")\n";
	##print "RC   : ", $rc      , " (",length($rc)     , ") -> ", $rcBin   , " (", length($rcBin)   , ") => ", $rcDec   , " (", length($rcDec)   , ") == ", &dec2bin($rcDec)   , " (",length(&dec2bin($rcDec))   , ")\n";
	#print "AND  : ", ($origDec & $compDec), " "x27, "=> ",&dec2bin(($origDec & $rcDec)),"\n";
	#print "OR   : ", ($origDec | $compDec), " "x26, "=> ",&dec2bin(($origDec | $compDec)),"\n";
	#print "XOR  : ", ($origDec ^ $compDec), " "x26, "=> ",&dec2bin(($origDec ^ $compDec)),"\n";
	##print "NEG: ", $orig    , " (",length($orig)   , ") -> ", $negBin  , " (", length($negBin)  , ") => ", $negDec  , " (",length($negDec) , ") == ", &dec2bin($negDec) , " (",length(&dec2bin($negDec))  , ")\n";
	#print "\n";
}

#close INFILE;

print "SUMMARY:
  TOTAL = $totalLines
";

sub dec2bin
{
	my $str = unpack("B30", pack("N", shift));
	$str =~ s/^0+(?=\d)//; #otherwise you will get leading zeroes
	return substr("0" x 30 . $str, -30);
}

sub bin2dec
{
	return unpack ("N", pack("B30", substr("0" x 30 . shift, -30)))
	#return substr("0"x30 . unpack ("N", pack("B30", shift)), -30);
}

1;
