#!/usr/bin/perl -w
use strict;
my $logToFile         = 0;
my $verbose           = 4;
my $generateArray     = 1;
my $saveArraytoFile   = 1;
my $loadArrayFromFile = 0;
my $printArray        = 1;
my $printArrayToFile  = 0;
my $memory            = 1;

my $tableSize         = 3; #sides of the table
my $numberRegisters   = 4; #number of columns per cell
my $fieldSize         = 2; # number of bytes per cell
my $cellSize          = $fieldSize * $numberRegisters; # in bytes
#my $blockSize        = 65536;

my $bitSize          = 12;
my $systemBinarity   = 32;

print "TABLE SIZE        : $tableSize x $tableSize (".($tableSize * $tableSize)." cells)
REGISTERS PER CELL: $numberRegisters (".($tableSize* $numberRegisters)." fields per line / ".(($tableSize * $tableSize) * $numberRegisters)." fields total)
BYTES PER REGISTER: $fieldSize (".join(" ", &convertBytes((($tableSize * $tableSize) * $numberRegisters * $fieldSize))).")\n";

my $dSize            = "%06d";
my $format1          = "BIN %".$bitSize."s (%012d)\n";
#my $format2          = "BIN1 %".$bitSize."s (%012d) BIN2 %".$bitSize."s (%012d)\n";
#my $format3          = "BIN1 %".$bitSize."s (%012d) AND BIN2 %".$bitSize."s (%012d) = COMP %".$bitSize."s (%012d)\n";

my $logFile          = $0 . ".log";
my $tableFile        = $0 . ".tab";
my $dataFile         = $0 . ".dat";

my $count            = 0;
my $maxValue         = -1;

if ( ! ( $generateArray || $loadArrayFromFile ))
{
	print "ARRAY MUST COME FROM SOMEWHERE. PLEASE CHECK SETTINGS\n";
	exit 1;
}
elsif ( ! ( $saveArraytoFile || $printArray ) && ( $memory ))
{
	print "ARRAY MUST GO SOMEWHERE. PLEASE CHECK SETTINGS\n";
	exit 2;
}

if ( $saveArraytoFile && ( ! $generateArray ))
{
	$saveArraytoFile = 0;
}

if ( $printArrayToFile && ( ! $printArray ))
{
	$printArrayToFile = 0;
}


my $std;
if ($logToFile)
{
	open LOG, ">", $logFile or die "COULD NOT OPEN LOG FILE $logFile: $!";
	$std = *LOG;
} else {
	$std = *STDOUT;
}

my $array;
if ( $generateArray     )
{
	$array = &generateArray();
	&saveArray($array)        if ( $saveArraytoFile && $memory);

} else {
	$array = &loadArray()     if ( $loadArrayFromFile && $memory );
}

&printArray($array)       if ( $printArray        );

close LOG if $logToFile;







sub generateArray
{
	print "#"x20 . "\n";
	print "GENERATING ARRAY\n";
	print "#"x20 . "\n";
	my $startTime = time;
	my $symArray = '';

	if ( ! $memory )
	{
		unlink($dataFile);
		open MEM, ">$dataFile" or die "COULD NOT OPEN MEMORY FILE $dataFile: $!";
		binmode(MEM);
	}

	for my $lineNum (0 .. $tableSize - 1)
	{
		my $seqBin    = &dec2bin($lineNum);
		#my $revSeqBin = &rcBin($seqBin);
		#my $revSeqNum = &bin2dec($revSeqBin);

		my $bin1;
		my $bin1Dec;

		#if ($seqNum <= $revSeqNum)
		#{
			$bin1    = $seqBin;
			$bin1Dec = $lineNum;
		#} else {
			#$bin1    = $revSeqBin;
			#$bin1Dec = $revSeqNum;
		#}

		if ( $verbose )
		{
			#printf $format1, $seqBin, $lineNum;
			my $size = &getSize(\$symArray);
			#print &eta($startTime, time, 0, $lineNum, $tableSize - 1, \$symArray) . "\n";
		}
		#printf $format1, $seqBin, $seqNum, $revSeqBin, $revSeqNum, $bin1, $bin1Dec;

		my $lineStartAbs = $lineNum      *   $tableSize  * $numberRegisters;
		my $lineEndAbs   = $lineStartAbs + ( $tableSize  * $numberRegisters ) - 1;
		my $lVec = '';

		print "LINE $lineNum :: LINE: start $lineStartAbs end $lineEndAbs\n";

		my $cellStartRel = 0;
		my $cellEndRel   = $tableSize * $numberRegisters - 1;
		my $cellStartAbs = $lineStartAbs;
		my $cellEndAbs   = $lineEndAbs;
		print "\tCELL :: REL: start $cellStartRel end $cellEndRel | ABS: start $cellStartAbs end $cellEndAbs\n";

		foreach my $colNum (0 .. $tableSize - 1)
		{
			my $colBin    = &dec2bin($colNum);
			#my $revColBin = &rcBin($colBin);
			#my $revColNum = &bin2dec($revColBin);

			my $bin2;
			my $bin2Dec;

			$bin2    = $colBin;
			$bin2Dec = $colNum;


			#printf "\t".$format1, $colBin, $colNum, $revColBin, $revColNum, $bin2, $bin2Dec;
			#printf $format2, $bin1, $bin1Dec, $bin2, $bin2Dec;
			#my $compORNum = (0+$bin1Dec | 0+$bin2Dec);
			#my $compORBin = &dec2bin($compORNum);
			#my $compXORNum = (0+$bin1Dec ^ 0+$bin2Dec);
			#my $compXORBin = &dec2bin($compXORNum);
			my $compANDDec = (0+$bin1Dec & 0+$bin2Dec);
			my $compANDBin = &dec2bin($compANDDec);
			#printf "\t\t$format3", $bin1, $bin1Dec, $bin2, $bin2Dec, $compANDBin, $compANDDec;
			##print map "$_\n", ("BIN1 ".$bin1, "BIN2 ".$bin2, "AND  ".$compANDBin, "OR   ".$compORBin, "XOR  ".$compXORBin);
			#print "\n\n";
			#$symArray[$bin1Dec][$bin2Dec] = $compANDDec;

			#     col1 col2 col3
			#row1 1x1  2x1  2x3
			#row2 2x1  2x2  2x3
			#row3 3x1  3x2  3x3

			#     col1 col2 col3
			#row1 1    2    3
			#row2 4    5    6
			#row3 7    8    9

			#row      |-----------|-----------|
			#cell     |-----|-----|-----|-----|
			#register |-|-|-|-|-|-|-|-|-|-|-|-|


			my $cellNumRelStart = 0;
			my $cellNumRelEnd   = $tableSize - 1;
			my $cellNumAbsStart = ( $lineNum * $tableSize * $numberRegisters ) + ( $colNum * $numberRegisters );
			my $cellNumAbsEnd   = $cellNumAbsStart + $numberRegisters - 1;

			print "\t\tCELL $colNum :: REL: start $cellNumRelStart end $cellNumRelEnd | ABS: start $cellNumAbsStart end $cellNumAbsEnd\n";
next;
			#printf $std " $dSize x $dSize = $dSize ".
			#"[LINE $dSize COL $dSize LINE START $dSize LINE END $dSize ".
			#"CELL ABS NUM $dSize CELL ABS POS $dSize CEL REL POS $dSize ".
			#"REGISTER ABS POS $dSize REGISTER REL POS $dSize] {$count}\n",
			#$lineNum, $colNum, $lineStart, $lineEnd, $celNumAbs, $el,
			#$compANDDec, $lineNum, $lineStart, $lineEnd, $relColPos, $absColPos if ( ($verbose > 1) || $logToFile);

			#printf "    BIN1DEC $dSize [$dSize] BIN2DEC $dSize [$dSize] COMPANDDEC $dSize [$dSize] COUNT $dSize [$dSize]\n", $bin1Dec, $relColPos+0, $bin2Dec, $relColPos+1, $compANDDec, $relColPos+2, $count, $relColPos+3  if ( ($verbose > 2) || $logToFile);
			$maxValue = $bin1Dec    > $maxValue ? $bin1Dec    : $maxValue;
			$maxValue = $bin2Dec    > $maxValue ? $bin2Dec    : $maxValue;
			$maxValue = $compANDDec > $maxValue ? $compANDDec : $maxValue;
			$maxValue = $count      > $maxValue ? $count      : $maxValue;

			#vec($lVec, $relRegisterNum+0, ($fieldSize*8)) = $bin1Dec;
			#vec($lVec, $relRegisterNum+1, ($fieldSize*8)) = $bin2Dec;
			#vec($lVec, $relRegisterNum+2, ($fieldSize*8)) = $compANDDec;
			#vec($lVec, $relRegisterNum+3, ($fieldSize*8)) = $count++;
		}

		if ( $memory )
		{
			$symArray .= $lVec;
		} else {
			use bytes;
			#print "ADDING ". &getSize(\$lVec) ." TO FH AT POS " . (($registerStart*$fieldSize)+$fieldSize) . ". NEXT ".(&getSizeBytes(\$lVec)+($registerStart*$fieldSize))."\n";
			#seek  MEM, (($registerStart*$fieldSize)+$fieldSize), 0 or die "COULD NOT SEEK: $!";
			print MEM  $lVec;
		}
	}

	if ( ! defined $symArray )
	{
		die "ERROR GENERATING ARRAY";
	} else {
		print "TOTAL $count\n";
	}

	if ( ! $memory )
	{
		close MEM;
	}

	return \$symArray;
}

exit;

sub saveArray
{
	my $dat = $_[0];
	print "#"x20 . "\n";
	print "SAVING ARRAY\n";
	die "NO DATA" if ( ! defined $dat );
	die "NO DATA" if ( ! length($dat) );
	print "SAVING " . &getSize($dat) . "\n";
	print "#"x20 . "\n";

	open DAT, ">$dataFile" or die "COULD NOT OPEN DAT FILE $dataFile: $!";
	binmode DAT;
	print DAT $$dat;
	close DAT;

	die "ERROR SAVING DAT" if ( ! -s $dataFile );
}

sub loadArray
{
	print "#"x20 . "\n";
	print "LOADING ARRAY\n";
	print "#"x20 . "\n";
	my $dat = '';
	open DAT, "<$dataFile" or die "COULD NOT OPEN DATA FILE $dataFile: $!";
	binmode DAT;
	my $buffer;
	while (
		read(DAT, $buffer, 65536) and $dat .= $buffer
		){};
	close DAT;

	die "ERROR LOADING ARRAY FROM FILE" if ( ! length($dat));
	die "ERROR LOADING ARRAY FROM FILE" if ( ! defined $dat );
	print "LOADED " . &getSize(\$dat) . "\n";

	return \$dat;
}

sub printArray
{
	print "#"x20 . "\n";
	print "PRINTING ARRAY\n";
	print "#"x20 . "\n";
	my $data         = $_[0];
	my $blockSizeLen = length($maxValue);
	my $celLen       = $numberRegisters * $blockSizeLen;
	my $bSize        = "%0".$blockSizeLen."d";

	my $tab;
	if ( $printArrayToFile )
	{
		open TAB, ">$tableFile" or die "COULD NOT OPEN LOG FILE $tableFile: $!";
		$tab = *TAB;
	} else {
		$tab = *STDOUT;
	}

	if ( ! $memory )
	{
		open MEM, "<$dataFile" or die "COULD NOT OPEN DATA FILE $dataFile: $!";
		binmode MEM;
	}

	print $tab "_"x$blockSizeLen, "_|_";
	my $sides = int((($numberRegisters*$blockSizeLen) + $numberRegisters - 1)/ 2) - $blockSizeLen;
	print $tab map "_"x$sides . "_" . (sprintf($bSize, $_)) . "\_" . "_"x$sides .($numberRegisters % 2 ? "" : "_"). "_._", (0 .. $tableSize - 1);
	print $tab "\n";

	for my $registerNumber (0 .. $tableSize - 1)
	{
		printf $tab "$bSize | ", $registerNumber;

		my $registerStart  = $registerNumber * (   $tableSize       * $numberRegisters );
		my $registerEnd    = $registerStart  + ( ( $tableSize - 1 ) * $numberRegisters );

		for my $colNumber (0 .. $tableSize - 1)
		{
			my $relColPos = $colNumber      *   $numberRegisters;
			my $absColPos = $registerStart  +   $relColPos;

			my $block = '';
			if ( $memory )
			{
				for (my $nc = 0; $nc < $numberRegisters; $nc++)
				{
					print "ABS COL POS $absColPos+$nc = ".($absColPos+$nc)."\n";
					$block .= vec($$data, $absColPos+$nc, ($fieldSize*8));
				}
				print "SIZE ".&getSize(\$block)."\n";
			} else {
				seek MEM, ($registerStart*$fieldSize), 0;
				read MEM, $block, $cellSize, 0;
			}

			#printf $std " $dSize x $dSize = $dSize [REGISTER $dSize REGISTER START $dSize REGISTER END $dSize REL CELL POS $dSize ABS CELL POS $dSize]\n", 0, 0, 0, $registerNumber, $registerStart, $registerEnd, $relColPos, $absColPos if ( ($verbose > 3) || $logToFile);

			for my $colCount (0 .. $numberRegisters - 1)
			{
				my $value;

				if ( $memory )
				{
					#$value = vec($$data, $absColPos+$colCount, ($fieldSize*8));
					$value = vec($block, $colCount, ($fieldSize*8));
				} else {
					#print "REGISTER $registerNumber START $registerStart REL COL POS $relColPos ABS COL POS $absColPos CELL POS ".($absColPos+$colCount)."\n";
					$value = vec($block, $colCount, ($fieldSize*8));
				}

				printf $tab "$bSize ", $value;
			}
			print $tab ". ";
		}
		print $tab "\n";
	}
	close TAB if $printArrayToFile;
	close MEM if ( ! $memory );
}








sub dec2bin
{
	my $num = $_[0];
	#print "D2B :: NUM $num\n";
	my $bNum = unpack("B32", pack("N", $num));
	#print "D2B ::   BNUM $bNum\n";
	$bNum = substr($bNum, -$bitSize);
	#print "D2B ::   BNUMF $bNum\n";
	#$bNum =~ s/^0+(?=\d)//; # fix left numbers
	return $bNum;
}

sub bin2dec
{
	my $bNum = $_[0];
	##print "B2D :: BNUM $bNum\n";
	#my $bNum32 = substr("0"x$systemBinarity . $bNum, -$systemBinarity);
	##print "B2D ::   BNUM32 $bNum32\n";
	#my $bNum32Pack = pack("B$systemBinarity", $bNum32);
	##print "B2D ::     BNUM32PACK $bNum32Pack\n";
	##my $bNum32PackUnpack = unpack("N", $bNum32Pack);
	#my $bNum32PackUnpack = unpack("N", $bNum32Pack);
	##print "B2D ::       BNUM32PACKUNPACK $bNum32PackUnpack\n";
	#return $bNum32PackUnpack;
	return unpack("N", pack("B$systemBinarity", substr("0"x$systemBinarity . $bNum, -$systemBinarity)));
}


sub rcBin
{
	my $bNum = $_[0];
	$bNum =~ tr/01/10/;
	$bNum = reverse($bNum);
	return $bNum;
}

sub getSize
{
	my $var   = $_[0];
	my $bytes =  &getSizeBytes($var);

	my ($size, $unity)  = &convertBytes($bytes);
	return "$size $unity";
}

sub convertBytes
{
	my $bytes = $_[0];
	my $size;
	my $unity;

	my $kb = 1024;
	my $mb = $kb * 1024;
	my $gb = $mb * 1024;

	if ( $bytes >= $gb )
	{
		$size = $bytes / $gb;
		$unity = "Gb";
	}
	elsif ( $bytes >= $mb )
	{
		$size = $bytes / $mb;
		$unity = "Mb";
	}
	elsif ( $bytes >= $kb )
	{
		$size = $bytes / $kb;
		$unity = "Kb";
	} else {
		$size = $bytes;
		$unity = "bytes";
	}

	if ( $unity ne 'bytes' )
	{
		$size = sprintf("%.2f", $size);
	}

	return ($size, $unity);
}

sub getSizeBytes
{
	my $var = $_[0];
	use bytes;
	my $bytes;

	if ( $memory )
	{
		$bytes = length($$var);
	} else {
		$bytes = -s $dataFile;
	}


	return $bytes;
}

sub eta
{
	my $startT       = $_[0];
	my $currT        = $_[1];
	my $startC       = $_[2];
	my $currC        = $_[3];
	my $targetC      = $_[4];
	my $var          = $_[5];
	my $sizeCurr     = &getSizeBytes($var);

	my $elapsedT     = $currT    - $startT;
	my $elapsedTstr  = &convertSeconds($elapsedT);
	my $elapsedC     = $currC    - $startC;
	my $avgT         = ( ! $elapsedT ? 1 : $elapsedT ) / ( ! $elapsedC ? 1 : $elapsedC );
	my $avgTstr      = &convertSeconds($avgT);
	my $avgC         = ( ! $elapsedC ? 1 : $elapsedC ) / ( ! $elapsedT ? 1 : $elapsedT );
	my $leftC        = $targetC  - $currC;
	my $leftT        = $leftC    * $avgT;
	my $leftTstr     = &convertSeconds($leftT);
	my $sizeUnity    = ( ! $sizeCurr ? 1 : $sizeCurr)/ ( ! $currC ? 1 : $currC );
	my $sizeEnd      = $sizeUnity * $targetC;
	my ($sizeCurrNum , $sizeCurrUni ) = &convertBytes($sizeCurr);
	my ($sizeEndNum  , $sizeEndUni  ) = &convertBytes($sizeEnd);
	my ($sizeUnityNum, $sizeUnityUni) = &convertBytes($sizeUnity);

	my $str          = sprintf("CURR c:$currC :: TARGET c:$targetC ::".
							   " ELAPSED t:$elapsedTstr c:$elapsedC :: AVG t:%s s/c c:%.2f c/s :: LEFT t:%s c:$leftC ::".
							   " SIZE curr: $sizeCurrNum $sizeCurrUni final: $sizeEndNum $sizeEndUni [$sizeUnityNum $sizeUnityUni / unity]",
							   $avgTstr, $avgC, $leftTstr);

	return $str;
}

sub convertSeconds
{
	my $sec   = $_[0];
	my $cMin  = 60;
	my $cHour = $cMin  * 60;
	my $cDay  = $cHour * 24;
	my $secs;
	my $mins;
	my $hours;
	my $days;

	if ( $sec >= $cDay )
	{
		$days = int($sec / $cDay );
		$sec -= $days * $cDay;
	}

	if ( $sec >= $cHour )
	{
		$hours = int($sec / $cHour );
		$sec  -= $hours * $cHour;
	}

	if ( $sec >= $cMin )
	{
		$mins  = int($sec / $cMin );
		$sec  -= $mins * $cMin;
	}

	$sec = sprintf("%.2f", $sec);

	my $str = ( $days ? "$days"."d " : '') . ( $hours ? "$hours"."h " : '') . ( $mins ? "$mins\" " : '') . ( $sec ? "$sec' " : '');
	return $str;
}
1;
