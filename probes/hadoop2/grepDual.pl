#!/usr/bin/perl -w

use warnings;
use strict;

my $outYes   = $ARGV[0];
my $outNop   = $ARGV[1];
my @patterns = @ARGV[2 .. (@ARGV-1)];

die "OUTPUT TO POSITIVE CONDITION NOT DEFINED" if ( ! defined $outYes   );
die "OUTPUT TO NEGATIVE CONDITION NOT DEFINED" if ( ! defined $outNop   );
die "NO PATTERT TO BE SEARCHED"                if ( ! scalar(@patterns) );

#print "SEARCHING FOR PATTERN \'",join("\';\'", @patterns),"\'\n";

open YES, ">$outYes" or die "COULD NOT OPEN $outYes TO OUTPUT: $!";
open NOP, ">$outNop" or die "COULD NOT OPEN $outNop TO OUTPUT: $!";

my $countYes = 0;
my $countNop = 0;

while (my $line = <STDIN>)
{
	my $nop = 0;
	for my $pattern (@patterns)
	{
		if ( index($line, $pattern) == -1)
		{
			#print "NOP :: $line";
			print NOP $line;
			$countNop++;
			$nop = 1;
			last;
		}
	}
	next if $nop;
	#print "YES :: $line";
	print YES $line;
	$countYes++;
}

close YES;
close NOP;

#print "YES: $countYes NOP: $countNop\n";

1;
