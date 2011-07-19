#!/usr/bin/perl -w
use strict;

my $indir = "output";
&genList("lig");

sub genList
{
	my $suffix = $_[0];
	opendir (DIR, "$indir") or die $!;
	my @infiles = grep /$suffix.wc$/, readdir(DIR);
	closedir DIR;
	my %answer;
	my @array1;
	my @array2;
	my %seen;

	foreach my $current (sort @infiles)
	{
		open ARRAY1, "<$indir/$current" or die "COULD NOT OPEN $indir/$current: $!";
		@array1 = sort <ARRAY1>;
		close ARRAY1;

		foreach my $element (@array1) { push(@{$seen{$element}}, $current); };

		foreach my $conCurrent (sort @infiles)
		{
			if ($conCurrent eq $current) { next; };
			print "$current vs. $conCurrent\n";
			my @union        = ();
			my @intersection = ();
			my @difference   = ();
			my %count = ();

			open ARRAY2, "<$indir/$conCurrent" or die "COULD NOT OPEN $indir/$conCurrent: $!";
			@array2 = sort <ARRAY2>;
			close ARRAY2;


			foreach my $element (@array1, @array2) { $count{$element}++ };

			foreach my $element (keys %count)
			{
# 				$seen{$current}{$element}++;
				push @union, $element;
				push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
			}
			$answer{$current}{$conCurrent} = \@difference;
			undef @array2;
		}
		undef @array1;
	}

	foreach my $current (sort keys %answer)
	{

		foreach my $conCurrent (sort keys %{$answer{$current}})
		{
			my @probes = $answer{$current}{$conCurrent};
			print "FILE $current ($suffix) HAVE THE FOLLOWING UNIQUE PROBES COMPARED WITH $conCurrent\n";
			foreach my $probe (sort @probes)
			{
				print "\t$probe";
			}
		}
	}

	foreach my $element (sort keys %seen)
	{
		if (@{$seen{$element}} == 1)
		{
			my $organism = ${$seen{$element}}[0];
			print "PROBE ($suffix) $element IS EXCLUSIVE TO ORGANISM $organism\n";
		}
		else
		{
			my $organism = join(", ", @{$seen{$element}});
			print "PROBE ($suffix) $element IS SHARED AMONG THE FOLLOWING ORGANISMS $organism\n";
		}
	}
}