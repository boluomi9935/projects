#!/usr/bin/perl
use strict;

my $windowsize = 6;
my $windowstep = 1;
my $minentropy = 0.721;
   $minentropy = 0.98;
my $wordlen    = 2;
my %ecount;
my $maskchar = "x";
my $log2     = log(2);

#http://biowiki.org/GffTools



sub entropy {
    my ($string) = @_;
    my %freq = ();
    my $total = 0;
    my $i;

    for ( my $i=0;$i<=(length($string) - $wordlen);$i++)
	{
		my $word = substr $string,$i,$wordlen;
		$freq{$word}++;
		$total++;
    }
    my $entropy = 0;
    foreach my $word (keys %freq) { $entropy -= ($freq{$word}/$total) * log($freq{$word}/$total); }

	if (0)
	{
		print "\nSTRING $string\t";
		foreach my $word (keys %freq) { 
			print "WORD $word\t";
		}
		print "ENTROPY " . $entropy / $log2 . "\t";
	}
    return $entropy / $log2;
}


sub mask 
{
	my $linepos  = 0;
	my $sequence = $_[0];
#	print "$sequence\n";
	my $output;
	if ($sequence)
	{
		my $maskstart   = -1;
		my $unmaskstart = -1;
		for (my $wpos=0;$wpos<length $sequence;$wpos++)
		{
			if ($wpos % $windowstep == 0)
			{
				if ($wpos<=length($sequence)-$windowsize || $wpos==0)
				{
					my $entropy = entropy(substr($sequence,$wpos,$windowsize));
					$ecount{$entropy}++;
					if ($entropy<$minentropy)
					{
						$unmaskstart = $wpos + $windowsize;
					}
				}
			}
			if ($wpos>=$unmaskstart) { $output .= substr($sequence,$wpos,1); }
			else { $output .= $maskchar; }
		}
	}
    return $output;
}

unless (@ARGV) { @ARGV = ("-"); }
foreach my $file (@ARGV) 
{
    open file, "<$file" or die "Couldn't open $file: $!";
    my $sequence;
    while (<file>) {
	if (/>/) {
	    #mask();
		print;
	} else {
	    if (/\S/) {
		s/\s//g;
		$sequence .= $_;
	    }
	}
    }
    close file;
	print "$sequence\n";
    print mask($sequence) . "\n";
}

1;
