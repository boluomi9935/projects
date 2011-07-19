#!/usr/bin/perl

use strict;
use warnings;
use String::Approx 'adist';
my $dimensions = 7;

#http://search.cpan.org/~jhi/String-Approx-3.26/Approx.pm

	my @inputs;
	open FILE, "<resultset.txt" or die "couldnt";
	while (<FILE>)
	{
		chomp;
		push(@inputs, $_);
	}

	$dimensions = @inputs;

	my @results;
	for (my $row = 0; $row < $dimensions; $row++)
	{
		my @dist = adist($inputs[$row], @inputs);
		$results[$row] = \@dist;
	}

	#print " "x11 . join(" ", @inputs[0 .. ($dimensions-1)]) . "\n";

	for (my $row = 0; $row < $dimensions; $row++)
	{
		#print "$inputs[$row] ";
		for (my $col = 0; $col < $dimensions; $col++)
		{
			#print $results[$row][$col] . " "x10;
		}
		#print "\n";
	}
	print "\n";




