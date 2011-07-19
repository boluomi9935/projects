sub digit2dna
{
	my $seq  = $_[0];

# 	print "$seq (" . length($seq) . ") > ";
	my $extra = "";
	if ( $seq =~ /([[:^lower:]]*)([[:lower:]]+)/)
	{
		$seq   = $1;
		$extra = uc($2);
	}
# 	print "$seq (" . length($seq) . ") + $extra (" . length($extra) . ") >> ";

	my $BASE = 4;
	my @str_digits;
	for (my $s = 0; $s < length($seq); $s+=2)
	{
		my $subSeq  = substr($seq, $s, 2);
		my $subs    = 0;

		$subSeq     = hex($subSeq);
		my @digits  = (0) x 4; # cria o array @digits composto de 4 zeros

		my $i = 0; 
# 		print "$subSeq\t";
		while ($subSeq) { # loop para decompor o numero
				$digits[4 - ++$i] = $subSeq % $BASE;
				$subSeq = int ($subSeq / $BASE);
		}
# 		print "@digits\t"; # imprime o codigo ascII transformado em base 4
		my $subJoin = join("", @digits);
		$subJoin =~ tr/0123/ACGT/;
# 		print "$subJoin\n"; # imprime o codigo ascII transformado em base 4
		push @str_digits, $subJoin;    # salva todos os codigos ascII em base
										# 4 gerados no array. cada elemento deste
									    # array ser� um outro array de 4 elementos..
	}
	my $join = join("", @str_digits);
# 	print "$join (" . length($join) . ") -> ";
	$join .= $extra;
# 	print "$join (" . length($join) . ")\n\n";
	return $join;
# 	print "Hex: $seq  " . length($seq)      . "\n";
# 	print "Seq: $join " . length($sequence) . "\n";
}

sub dna2digit
{
	my $input = uc($_[0]);
	my $extra = "";
# 	print "$input (" . length($input) . ") > ";
	while (length($input) % 4) { $extra = chop($input) . $extra; };

# 	print "$input (" . length($input) . ") + $extra (" . length($extra) . ")";

#     print "Seq: $input " . length($input) . "\n";
	$input =~ s/\r//g;
	$input =~ s/\n//g;
	$input =~ tr/ACGTacgt/01230123/;
# 	print "Inp: $input "    . length($input)    . "\n";
	my $outputHex; my $outputHexStr;
	my $outputDec; my $outputDecStr;

	for (my $i = 0; $i < length($input); $i+=4)
	{
		my $subInput = substr($input, $i, 4);
		#print "$i - $subInput\n";
# 		my $subInputDec = $subInput;
		my $subInputHex = $subInput;

		$subInputHex =~ s/(.)(.)(.)(.)/(64*$1)+(16*$2)+(4*$3)+$4/gex;
# 		$subInputDec =~ s/(.)(.)(.)(.)/(64*$1)+(16*$2)+(4*$3)+$4/gex;

		$subInputHex = sprintf("%X", $subInputHex);
		if (length($subInputHex) <   2) {$subInputHex = "0$subInputHex"; };
# 		if ($subInputDec         < 100) {$outputDecStr .= "_" ; };

		$outputHex    .= $subInputHex;
# 		$outputHexStr .= "__" . $subInputHex;
# 
# 		$outputDec    .= $subInputDec;
# 		$outputDecStr .= "_" . $subInputDec;
	}
	if ($extra)
	{
		$outputHex .= lc($extra);
	}
# 	print " >> $outputHex (" . length($outputHex) . ")\n";
# 	&digit2dna($outputHex);
# 	print "Dec: $outputDecStr " . length($outputDec) . "\n";
# 	print "Hex: $outputHexStr " . length($outputHex) . "\n";
	return $outputHex;
}


