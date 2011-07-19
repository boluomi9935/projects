#!/usr/bin/perl -w
use strict;
use lib "./filters";

my $totalLines = 0;
my $strLen     = 30;
my $binSize    = ($strLen*2+2);
my ($k, $rK)   = &loadKeys();
$| = 1;

my $lastSeq    = "";
my $lastSeqBin = "";
my $lastSeqDec = "";

while (my $line = <STDIN>)
{
	$totalLines++;
	chomp $line;
	(my $orig, my $pos) = split("\t", $line);

	my $origBin     = &dna2bin($orig, 1);
	my $origHex     = &bin2hex($origBin);
	my $origBinBack = &hex2bin($origHex);
	my ($origBack, $origFrame) = &bin2dna($origBinBack);

	my $rc          = &rc($orig);
	my $rcBin       = &dna2bin($rc, 0);
	my $rcHex       = &bin2hex($rcBin);
	my $rcBinBack   = &hex2bin($rcHex);
	my ($rcBack, $rcFrame) = &bin2dna($rcBinBack);

	if ($origHex gt $rcHex)	{ print $origHex, "\t", $pos, "\n"; }
	else 					{ print $rcHex,   "\t", $pos, "\n"; }
}


sub rc
{
	my $orig = $_[0];
	$orig    =~ tr/ACGT/TGCA/;
	$orig    =  reverse($orig);

	return $orig;
}

sub dna2bin
{
	my $dna   = $_[0];
	my $frame = $_[1];
	$dna    =~ s/A/00/g;
	$dna    =~ s/C/01/g;
	$dna    =~ s/G/10/g;
	$dna    =~ s/T/11/g;
	if ($frame)	{ $dna   .= "00"; }
	else        { $dna   .= "01"; }
}

sub bin2dna
{
	my $bin = $_[0];
	my $dna = "";
	my $frame;
	#print "B2D :: BIN $bin [",length($bin),"]\n";

	$frame = substr($bin, length($bin)-2, 2);
	#print "B2D :: FRAME $frame\n";

	$bin = substr($bin, (length($bin)-(($strLen*2)+2)), ($strLen*2));
	#print "B2D :: BIN $bin [",length($bin),"]\n";

	for (my $b = length($bin); $b >= 0; $b-=2)
	{
		my $sub = substr($bin, $b, 2);
		$sub    =~ s/00/A/g;
		$sub    =~ s/01/C/g;
		$sub    =~ s/10/G/g;
		$sub    =~ s/11/T/g;
		$dna    = $sub . $dna;
	}
	#print "B2D :: DNA $dna [",length($dna),"]\n";

	return ($dna, $frame);
}

sub bin2hex
{
	my $bStr = shift;
	#print "B2H :: BSTR $bStr [",length($bStr),"]\n";
	if ( length($bStr) % 6 ) { $bStr = "0"x(6-(length($bStr) % 6)) . $bStr; };
	#print "B2H :: BSTR $bStr [",length($bStr),"]\n";

	my $hStr = "";
	for (my $s = 0; $s < length($bStr); $s += 6)
	{
		my $sub = substr($bStr, $s, 6);
		$hStr  .= $k->{$sub};
		#print "\tSUB $sub > ",$k->{$sub},"\n";
	}
	#print "B2H :: HSTR $hStr [",length($hStr),"]\n\n";

	return $hStr;
}


sub hex2bin
{
	my $hStr   = shift;
	my $bStr;
	#print "H2B :: HSTR $hStr [",length($hStr),"]\n";
	for (my $c = 0; $c < length($hStr) ; $c++)
	{
		my $sub = substr($hStr,$c,1);
		$bStr .= $rK->{$sub};
		#print "\tSUB $sub > ",$rK->{$sub},"\n";
	}
	#print "H2B :: BSTR $bStr [",length($bStr),"]\n\n";
	return $bStr;
}


sub loadKeys
{
	my %keys;
	my %rKeys;
	my @binary  = qw(0 1);
	my @letters = qw(0 1 2 3 4 5 6 7 8 9 a A b B c C d D e E f F g G h H i I j J k K l L m M n N o O p P q Q r R s S t T u U v V w W x X y Y z Z + -);
	#                0                 1                   2                   3                   4                   5                   6       64
	#                                  10                  20                  30                  40                  50                  60
	my $c = 0;
	foreach my $k0 (@binary) #2
	{
	foreach my $k1 (@binary) #4
	{
	foreach my $k2 (@binary) #8
	{
	foreach my $k3 (@binary) #16
	{
	foreach my $k4 (@binary) #32
	{
	foreach my $k5 (@binary) #64
	{
		$keys{"$k0$k1$k2$k3$k4$k5"} = $letters[$c];
		$rKeys{$letters[$c]}        = "$k0$k1$k2$k3$k4$k5";
		$c++;
	}
	}
	}
	}
	}
	}
	return (\%keys, \%rKeys);
}





#sub dec2bin
#{
#	my $shift   = shift;
#	my $pack    = pack("N", $shift);
#
#	my $unpack = unpack("B".$binSize, $pack);
#	$unpack =~ s/^0+(?=\d)//; #otherwise you will get leading zeroes
#	my $substr = substr("0" x $binSize . $unpack, -$binSize);
#
#	print "DEC2BIN :: SHIFT $shift PACK $pack UNPACK $unpack SUBSTR $substr\n";
#	return $substr;
#	#my $str = unpack("B".$binSize, pack("N", shift));
#	#return substr("0" x $strLen . $str, -$strLen);
#}
#
#sub bin2dec
#{
#	my $substr = substr("0" x  $binSize . shift, -$binSize);
#	my $pack   = pack("B".$binSize, $substr);
#	my $return = unpack ("N", $pack);
#	print "BIN2DEC :: BINSIZE $binSize SUBSTR $substr PACK $pack RETURN $return\n";
#	return $return;
#	#return unpack ("N", pack("B".$binSize, substr("0" x $binSize . shift, -$binSize)))
#	#return substr("0"x30 . unpack ("N", pack("B30", shift)), -30);
#}
#
#
#sub bin2hex2
#{
#	my $substr = substr("0" x  $binSize . shift, -$binSize);
#	my $pack   = pack("B".$binSize, $substr);
#	my $return = unpack ("H16", $pack);
#	print "HEX2DEC :: BINSIZE $binSize SUBSTR $substr PACK $pack RETURN $return\n";
#	return $return;
#	#return unpack ("N", pack("B".$binSize, substr("0" x $binSize . shift, -$binSize)))
#	#return substr("0"x30 . unpack ("N", pack("B30", shift)), -30);
#}
#
#
#sub hex2bin2
#{
#	my $shift   = shift;
#	my $pack    = pack("N", unpack("H16", $shift));
#
#	my $unpack = unpack("B".$binSize, $pack);
#	$unpack =~ s/^0+(?=\d)//; #otherwise you will get leading zeroes
#	my $substr = substr("0" x $binSize . $unpack, -$binSize);
#
#	print "HEX2BIN :: SHIFT $shift PACK $pack UNPACK $unpack SUBSTR $substr\n";
#	return $substr;
#	#my $str = unpack("B".$binSize, pack("N", shift));
#	#return substr("0" x $strLen . $str, -$strLen);
#}
#
#
#
#
#sub b2h
#{
#	my $num   = shift;
#	my $WIDTH = 32;
#	my $index = length($num)-$WIDTH;
#	print "index = $index\n";
#	my $hex="";
#
#	do
#	{
#		my $width = $WIDTH;
#		if ($index < 0)
#		{
#			$width += $index;
#			$index = 0;
#		}
#
#		my $cut_string = substr($num,$index,$width);
#		print "index is $index width is $width Cut String is $cut_string\n";
#		$hex = sprintf('%X', oct("0b$cut_string")). $hex;
#		$index -= $WIDTH;
#	} while ($index > (-1 * $WIDTH));
#
#	return $hex;
#}

1;
