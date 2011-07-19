#!/usr/bin/perl

use strict;
use warnings;
use String::Approx 'adist';

#http://search.cpan.org/~jhi/String-Approx-3.26/Approx.pm

	my @inputs;
	$inputs[0] = 'CCTCTTGGCAGGAAGTTTTT';
	$inputs[1] = 'ACTGCCTGCACTTGCTGTGT';
	$inputs[2] = 'CCTCTTGGGATGTGCCTGTA';
	$inputs[3] = 'CATCCTCTTCCTCTTCCTCT';
	$inputs[4] = 'CATGTCCTCCTGATGTTATA';
	$inputs[5] = 'AGACACTGTCATTTGTGTGT';

#	print "match" if amatch("foobar", "fooar");

#	my @catches = amatch($inputs[1], ['10%'], @inputs);
#	print join("\t", @catches);

	my @dist = adist($inputs[1], @inputs);
	for (my $i = 0; $i < @inputs; $i++)
	{
		print "$inputs[1] vs $inputs[$i] = $dist[$i]\n";
	}
		print "\n";








#my $skipAirpin = 1; #skip sequence which m13 and lig are complementar
#my $airpinTheshold = 20; # percentage of similarities allowed
#use String::Approx 'aindex';
#if($skipAirpin)
#{
#	my $revM13Seq = reverse($MKFm13Seq);
#	my $dist = aindex($MKFligSeq, ["$airpinTheshold%"], $revM13Seq);
#	print "$MKFligSeq vs $revM13Seq > $dist\n" if ($dist >= 0);
#}
