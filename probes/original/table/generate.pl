#!/usr/bin/perl -w
use strict;
use Bit::Vector;

my $desiredLength = 24;
my $max           = (2 ** ($desiredLength*2));
my @letters;
$letters[0] = 'A';
$letters[1] = 'C';
$letters[2] = 'G';
$letters[3] = 'T';
my $granularity = 100_000;

my $startTime = time;
open DB1, ">db1" or die "COULD NOT OPEN db1";
#open DB2, ">db2" or die "COULD NOT OPEN db1";

my $str = "";
my @pieces;
for (my $i = 0; $i < $max; $i++)
{
	if ( ! ( $i % $granularity) )
	{
		my $cTime   = time - $startTime;
		if ( $cTime )
		{
			my $speed   = int($i / $cTime);
			my $missing = $max - $i;
			my $eta     = int($missing / $speed);
			my $percent = int(($i/$max)*100);
			$| = 1;
			printf "%8d of %8d ( %8d to go ) %3d%%; speed = %6d seqs/second; eta %6d s et %6d s\n", $i, $max, $missing, $percent, $speed, $eta, $cTime;
			$| = 0;
		}
	};

	my $var = Bit::Vector->new_Dec(64, $i);
	#my $bin = substr($var->to_Bin(),-($desiredLength*2));
	#printf "I %7d B (%".($desiredLength*2)."s) [%2d]\n", $i, $bin,length($bin);
	$str = "";
	@pieces = ();
	@pieces = $var->Chunk_List_Read(2);
	for (my $pn = 0; $pn < $desiredLength; $pn++)
	{
		#print "\tPIECE $pn = ", $pieces[$pn], " => ",$letters[$pieces[$pn]],"\n";
		$str .= $letters[$pieces[$pn]];
	}
	#printf "I %7d = %".$desiredLength."s %d\n", $i, $str, length($str);
	print DB1 $i,   "\t", $str, "\n";
	#print DB2 $str, "\t", $i,   "\n";
}

close DB1;
#close DB2;

1;
