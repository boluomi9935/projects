package dnaCodeOO;
# Saulo Aflitos
# 2009 06 18 19 47

use strict;
use warnings;


if (0) { &autotest(); };

our @EXPORT = qw ( digit2dna dna2digit );

sub new {
    my $class = shift;
    my $self  = {}; 
    
    $self->{A_dnaKey}        = ();
    $self->{A_DIGIT_TO_CODE} = ();
    $self->{A_CODE_TO_DIGIT} = ();
    $self->{H_keyDna}        = ();
    $self->{H_alphabet}      = ();
    
    &loadVariables($self);
    
    bless($self, $class);
    
    return $self;
}




sub autotest{
	my @strs;
	$strs[0] = "A";
	$strs[1] = "AA";
	$strs[2] = "AAA";
	$strs[3] = "AAAA";
	$strs[4] = "ACGT";
	$strs[5] = "TGCAACTG";

#Cryptococcus_neoformans_var_neoformans_JEC21_CHROMOSSOMES.fasta.10.14.R.sql
#'214684.0','438716','438681','438645','R','11','1','DxmR9SRUS47gc','49','80','>zlMozlMn05rt','59','85','DxmR9SRUS47KZ>bIo>bIj0oF','54','92',':jyzqYgg'
#Cryptococcus_neoformans_var_neoformans_B3501A_CHROMOSSOMES.fasta.6.9.R.sql
#'283643.0','893287','893254','893218','R','7','1','u]qW252N0]+','58','82','rkELHv0Jj4vkc','59','85','u]qW252N0]+rkELHv0Jj4vkc','59','94','BhRp4rgg')
	my @rev;
	$rev[0] = "DxmR9SRUS47gc";
	$rev[1] = ">zlMozlMn05rt";
	$rev[2] = "DxmR9SRUS47KZ>bIo>bIj0oF";
	$rev[3] = "jyzqYgg";
	$rev[4] = "u]qW252N0]+";
	$rev[5] = "rkELHv0Jj4vkc";
	$rev[6] = "u]qW252N0]+rkELHv0Jj4vkc";
	$rev[7] = "BhRp4rgg";
	$rev[8] = "KYioJP5Y8j/Q9M>iye.rYc";
#PASS: DxmR9SRUS47gc > GACCTCCATGTGAGCGTTGTGTAAGTTACAACTGC
#PASS: >zlMozlMn05rt > TTCCTTCAGGGCCCCCTTCAGGGCCCAAAAACCCGAT
#PASS: DxmR9SRUS47KZ>bIo>bIj0oF > GACCTCCATGTGAGCGTTGTGTAAGTTACAACTGCTTCCTTCAGGGCCCCCTTCAGGGCCCAAAAACCCGAT
#PASS: jyzqYgg > CAACTGCTTCCTTCAGG
#PASS: u]qW252N0]+ > CGGTGGCCTTAGAAGACCAAGGGGAAATGGTGC
#PASS: rkELHv0Jj4vkc > CGACACGAGGGAGCACGTAAAGCGCAAACACGTCACC
#PASS: u]qW252N0]+rkELHv0Jj4vkc > CGGTGGCCTTAGAAGACCAAGGGGAAATGGTGCCGACACGAGGGAGCACGTAAAGCGCAAACACGTCACC
#PASS: BhRp4rgg > GAAATGGTGCCGACACGAGG


	foreach my $str (@strs)
	{
		my $d2n = &dna2digit($str);
		my $n2d = &digit2dna($d2n);
		if ($str ne $n2d)
		{
			die "ERROR: $str DIFF $n2d";
		}
		else
		{
			print "PASS: $str EQUAL $n2d\n";
		}
	}
	
	foreach my $str (@rev)
	{
		my $n2d = &digit2dna($str);
		print "PASS: $str > $n2d\n";

	}
}

#######################################
####### CORE FUNCTIONS
#######################################
sub digit2dna($)
{
    my $self      = shift;
	my $seq       = $_[0];
	my $lengthSeq = length($seq);
	my $outSeq;
# 	print "$seq (" . length($seq) . ") > ";
	my $extra = "";
	($seq, $extra) = &splitDigit($seq);

	if ($lengthSeq != length("$seq$extra")) { die "ERROR UMPACKING DNA"; };

#	print "$seq (" . length($seq) . ") + $extra (" . length($extra) . ") >> ";

	for (my $s = 0; $s < length($seq); $s+=1)
	{
		my $subSeq  = substr($seq, $s, 1);
		$outSeq    .= $self->{A_dnaKey}[$self->{A_CODE_TO_DIGIT}{$subSeq}];
	}

# 	print "$outSeq (" . length($outSeq) . ") -> ";
	$outSeq .= $extra;
# 	print "$outSeq (" . length($outSeq) . ")\n\n";
	return $outSeq;
}

sub dna2digit($)
{
    my $self  = shift;
	my $input = uc($_[0]);
	my $extra = "";
	my $outPut;
# 	print "$input (" . length($input) . ") > ";
	while (length($input) % 3) { $extra = chop($input) . $extra; };

# 	print "$input (" . length($input) . ") + $extra (" . length($extra) . ")";

#   print "Seq: $input " . length($input) . "\n";
	$input =~ s/\r//g;
	$input =~ s/\n//g;

	for (my $i = 0; $i < length($input); $i+=3)
	{
		my $subInput = substr($input, $i, 3);
		#die "$subInput doesnt exists" if ( ! exists $keyDna{$subInput} );
		#die $self->{A_DIGIT_TO_CODE}[$keyDna{$subInput}] . " DOESNT EXISTS" if ( ! defined $self->{A_DIGIT_TO_CODE}[$keyDna{$subInput}] );
		$outPut     .= $self->{A_DIGIT_TO_CODE}[$self->{H_keyDna}{$subInput}];
		#) or die "SUB INPUT: $subInput KEYDNA: ", $keyDna{$subInput}, " ", $self->{A_DIGIT_TO_CODE}[$keyDna{$subInput}], "\n";
	}

	if ($extra)
	{
		$outPut .= lc($extra);
	}
# 	print " >> $outPut (" . length($outPut) . ")\n";
# 	&digit2dna($outputHex);
# 	print "Dec: $outputDecStr " . length($outputDec) . "\n";
# 	print "Hex: $outputHexStr " . length($outputHex) . "\n";
	return $outPut;
}

sub dna2number($)
{
    my $self  = shift;
	my $input = uc($_[0]);
	my $extra = "";
	my $outPut;
	while (length($input) % 3) { $extra =  $self->{H_alphabet}{chop($input)} . $extra; };

	$input =~ s/\r//g;
	$input =~ s/\n//g;

	for (my $i = 0; $i < length($input); $i+=3)
	{
		my $subInput = substr($input, $i, 3);
		$outPut     .= ($self->{H_keyDna}{$subInput} < 10) ? "0$self->{H_keyDna}{$subInput}" : $self->{H_keyDna}{$subInput};
	}

	if ($extra)
	{
		$outPut .= $extra;
	}

	return $outPut;
}


sub digit2number($)
{
    my $self      = shift;
	my $seq       = $_[0];
	my $lengthSeq = length($seq);
	my $outSeq;

	for (my $s = 0; $s < $lengthSeq; $s+=1)
	{
		my $subSeq  = substr($seq, $s, 1);
		$outSeq    .= ($self->{A_CODE_TO_DIGIT}{$subSeq} < 10) ? "0$self->{A_CODE_TO_DIGIT}{$subSeq}" : $self->{A_CODE_TO_DIGIT}{$subSeq};
	}

	return $outSeq;
}

#######################################
####### COMPARE FUNCTIONS
#######################################
sub compDigit($$)
{
	my $digit1 = $_[0];
	my $digit2 = $_[1];

#	print "\tCOMPARING NORMAL vs NORMAL: ", $digit1, " WITH ", $digit2, "\n";
	if ($digit1 =~ /\Q$digit2/) { return 100_000; };
	if ($digit2 =~ /\Q$digit1/) { return 100_000; };


	my $digit2Rc  = &digit2digitrc($digit2);
	my $digit1Rc  = &digit2digitrc($digit1);
#	print "\tCOMPARING NORMAL vs RC: ", $digit1, " WITH ", $digit2Rc, "\n";
	if ($digit2Rc =~ /\Q$digit1/)   { return 200_000; };
	if ($digit1   =~ /\Q$digit2Rc/) { return 200_000; };


	my $digit1S;
	my $digit2S;
	($digit1S, ) = &splitDigit($digit1);
	($digit2S, ) = &splitDigit($digit2);
#	print "\tCOMPARING STRIPED vs STRIPED: ", $digit1S, " WITH ", $digit2S, "\n";
	if ($digit1S =~ /\Q$digit2S/) { return 300_000; };
	if ($digit2S =~ /\Q$digit1S/) { return 300_000; };



	my $digit1SRc = &digit2digitrc($digit1S);
	my $digit2SRc = &digit2digitrc($digit2S);
#	print "\tCOMPARING STRIPED vs NORMAL RC: ", $digit1S, " WITH ", $digit2Rc, "\n";
	if ($digit2Rc =~ /\Q$digit1S/)  { return 400_000; };
	if ($digit1Rc =~ /\Q$digit2S/)  { return 400_000; };
	if ($digit2S  =~ /\Q$digit1Rc/) { return 400_000; };
	if ($digit1S  =~ /\Q$digit2Rc/) { return 400_000; };



#	print "\tCOMPARING STRIPED vs STRIPED RC: ", $digit1S, " WITH ", $digit2SRc, "\n";
	if ($digit1    =~ /\Q$digit2SRc/) { return 500_000; };
	if ($digit2SRc =~ /\Q$digit1/)    { return 500_000; };

	return 0;
}

sub digit2digitrc($)
{
	my $digit = \$_[0];
	my $dna   = &revComp(&digit2dna($$digit));
	return &dna2digit($dna);
}




#######################################
####### AUXILIAR FUNCTIONS
#######################################
sub splitDigit($)
{
	my $seq   = $_[0];
	my $extra = "";
	if ( $seq =~ /([^a|c|g|t|A|C|G|T]*)([a|c|g|t|A|C|G|T]*)/)
	{
		$seq   = $1;
		$extra = uc($2);
	}
	return ($seq, $extra);
}



sub revComp($)
{
	my $sequence = uc($_[0]);
	my $rev = reverse($sequence);
	$rev =~ tr/ACTG/TGAC/;
	return $rev;
}



#######################################
####### SETUP FUNCTIONS
#######################################
sub loadVariables
{
#	my @dnaRevKey;

    #$self->{A_dnaKey}        = ();
    #$self->{A_DIGIT_TO_CODE} = ();
    #$self->{A_CODE_TO_DIGIT} = ();
    #$self->{H_keyDna}        = ();
    #$self->{H_alphabet}      = ();
    my $self = $_[0];
    
	$self->{H_alphabet}{"A"} = 65;
	$self->{H_alphabet}{"C"} = 66;
	$self->{H_alphabet}{"G"} = 67;
	$self->{H_alphabet}{"T"} = 68;

	foreach my $st (sort keys %{$self->{H_alphabet}})
	{
		foreach my $nd (sort keys %{$self->{H_alphabet}})
		{
			foreach my $rd (sort keys %{$self->{H_alphabet}})
			{
				my $seq = "$st$nd$rd";
				push(@{$self->{A_dnaKey}}, $seq);
#				push(@dnaRevKey, &revComp($seq));
			}
		}
	}

	#TODO: TAKE "-" OUT BECAUSE OF ALIGNMENT
	@{$self->{A_DIGIT_TO_CODE}} = qw (0 1 2 3 4 5 6 7 8 9 b d e f h i j k l m n o p q r s u v w x y z B D E F H I J K L M N O P Q R S U V W X Y Z / - = + ] [ : > < . ? );
	#  COUNT             1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 
	#                    1                 10                  20        25        30        35        40  42              50                  60        65
	#  INDEX             0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 
	#                    0                   10                  20        25        30        35        40  42              50                  60      64

	for (my $k = 0; $k < @{$self->{A_dnaKey}}; $k++)
	{
		$self->{H_keyDna}{$self->{A_dnaKey}[$k]} = $k;
	}

	for (my $i = 0; $i < @{$self->{A_DIGIT_TO_CODE}}; $i++)
	{
		$self->{A_CODE_TO_DIGIT}{$self->{A_DIGIT_TO_CODE}[$i]} = $i;
	}

	my %keydnaCode;
	my %keycodeDna;
	for (my $k = 0; $k < @{$self->{A_dnaKey}}; $k++)
	{
		$keydnaCode{$self->{A_dnaKey}[$k]} = $self->{A_DIGIT_TO_CODE}[$k];
	}

	for (my $k = 0; $k < @{$self->{A_DIGIT_TO_CODE}}; $k++)
	{
		$keycodeDna{$self->{A_DIGIT_TO_CODE}[$k]} = $self->{A_dnaKey}[$k];
	}

#@{$self->{A_dnaKey}}[0] = aaa
#@{$self->{A_dnaKey}}[1] = aac
#@{$self->{A_dnaKey}}[2] = aag

#%keyDna{aaa} = 0
#%keyDna{aac} = 1
#%keyDna{aag} = 2

#@{$self->{A_DIGIT_TO_CODE}}[0] = b
#@{$self->{A_DIGIT_TO_CODE}}[1] = d
#@{$self->{A_DIGIT_TO_CODE}}[2] = e

#@CODE_TO_DIGIT{b} = 0
#@CODE_TO_DIGIT{d} = 1
#@CODE_TO_DIGIT{e} = 2

#%keyDnaCode{aaa} = b
#%keyDnaCode{aac} = d
#%keyDnaCode{aag} = e

#%keyCodeDna{b} = aaa
#%keyCodeDna{d} = aac
#%keyCodeDna{e} = aag

#&dna2digit
#$self->{A_DIGIT_TO_CODE}[$keyDna{$subInput}];

#&digit2dna
#$self->{A_dnaKey}[$self->{A_CODE_TO_DIGIT}{$subSeq}];
}


1;







1;
