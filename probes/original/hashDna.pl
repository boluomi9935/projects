#!/usr/bin/perl -w
use warnings;
use strict;

my %hash;
my @array;
my %sppHash;

#my $line = "z7Zvm0kL	381046,4934";
my $countLine = 0;
$| = 1;
my $sTime = time;
while (my $line = <STDIN>)
{
	$countLine++;
	print "LINE $countLine IN ",(time-$sTime),"\n" if ( ! ($countLine % 10_000));
	chomp $line;
	
	#$line =~ s/\s+/ /;
	next if (length($line) <= 9);
	next if ( ( ! defined $line ) || ( $line eq '' ) || ( $line eq ' ' ));
	
	my ($seq, $var) = (substr($line,0,8), substr($line,9));
	
	if ( ! defined $sppHash{$var} ) { $sppHash{$var} = scalar(keys %sppHash) };
	
	my $result = &getOrdBin($seq);
	
	#print "SEQ \"$seq\" VAR \"$var\"\n";
	push(@{$array[$result->[0]][$result->[1]][$result->[2]][$result->[3]][$result->[4]][$result->[5]][$result->[6]][$result->[7]]}, ($seq, $sppHash{$var}));
	#$hash{$seq} = $sppHash{$var};
}

foreach my $var (keys %sppHash)
{
	print "VAR: $var\n";
}

sleep 20;



sub getOrdBin
{
	my $in = $_[0];
	my @ords;
	
	for (my $pos = 0; $pos < length($in); $pos++)
	{
		my $char = substr($in, $pos, 1);
		my $val  = ord($char) - 40;
		#print "$char $val\n";
		if ($val > 40) { $val = 1 } else { $val = 0 };
		push(@ords, $val);
	}
	
	return \@ords;
}


sub getOrd
{
	my $in = $_[0];
	my @ords;
	
	for (my $pos = 0; $pos < length($in); $pos++)
	{
		my $char = substr($in, $pos, 1);
		my $val  = ord($char) - 40;
		push(@ords, $val);
	}
	
	return \@ords;
}

1;
