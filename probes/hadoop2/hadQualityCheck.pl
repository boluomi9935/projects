#!/usr/bin/perl -w
use strict;
use lib "./filters";
use loadconf;
use complexity;
use folding;

my %pref  = &loadconf::loadConf;

&loadconf::checkNeeds( "PCR.minRepeatLegth", "PCR.minRepeatNumber", "PCR.minRepeatNumber");

my $minRepeatLegth  = $pref{"PCR.minRepeatLegth"};
my $mimRepeatNumber = $pref{"PCR.minRepeatNumber"};
my $minRepeatNumber = $pref{"PCR.minRepeatNumber"};
my $totalLines      = 0;
my $okLines         = 0;
my $failedMask      = 0;
my $failedFold      = 0;

my $inFile = $ARGV[0];
die "NO INPUT FILE DEFINED" if ( ! defined $inFile );
die "FILE $inFile DOESNT EXISTS" if ( ! -f $inFile );

my $maskFile = $inFile . ".mask";
my $foldFile = $inFile . ".fold";
my $logFile  = $inFile . ".log";
my $outFile  = $inFile . ".pass.had";

open INFILE,   "<$inFile"   or die "COULD NOT OPEN $inFile   : $!";
open MASKFILE, ">$maskFile" or die "COULD NOT OPEN $maskFile : $!";
open FOLDFILE, ">$foldFile" or die "COULD NOT OPEN $foldFile : $!";
open OUTFILE,  ">$outFile"  or die "COULD NOT OPEN $outFile  : $!";
open LOGFILE,  ">$logFile"  or die "COULD NOT OPEN $logFile  : $!";


while (my $line = <INFILE>)
{
	$totalLines++;
	chomp $line;
	(my $seq, my $pos) = split("\t", $line);

	my $mask  = &complexity::masker($seq, $minRepeatLegth, $minRepeatNumber);
	if ( ! defined $mask) { die "MASKER RETURNED NULL"; };
	if ($mask) { print MASKFILE $line, "\n"; $failedMask++; next; };

	my $seqFold = &folding::checkFolding($seq);
	if ($seqFold) { print FOLDFILE $line, "\n"; $failedFold++; next; };
	$okLines++;
	print OUTFILE $line, "\n";
}

print LOGFILE time, "\nSUMMARY:
TOTAL = $totalLines
OK    = $okLines
NO    = ", ($totalLines - $okLines), "
 MASK = $failedMask
 FOLD = $failedFold
";

close LOGFILE;
close OUTFILE;
close FOLDFILE;
close MASKFILE;
close INFILE;




1;
