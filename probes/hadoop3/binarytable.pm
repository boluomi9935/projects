package binarytable;
use binStorage;
use varSize;
require Exporter;

@ISA       = qw{Exporter};
@EXPORT_OK = qw{new};
use strict;
use warnings;

my $dSize     = "%06d";
my $logFile   = "binary.log";
my $tableFile = "binary.tab";

my $count     = 0;
my $maxValue  = 1;
my $step      = 5;
my $bitSize;
my $systemBinarity;
my $memory;

my $std;

sub new
{
    my $class = shift;
    my $self  = bless {}, $class;
    my %vars  = @_;

    my %defaults = (
        bitSize           => 12,   # int    : number of bit necessary to each field
        generateArray     => 1,    # boolean: generate array
        loadArrayFromFile => 0,    # boolean: load array from file
        logToFile         => 1,    # boolean: log output to file
        memory            => 0,    # boolean: 0=disk 1=memory
        numberRegisters   => 4,    # int    : number of fields per cell
        printArray        => 0,    # boolean: print array table
        printArrayToFile  => 0,    # boolean: print array table to file or screen
        saveArraytoFile   => 1,    # boolean: save array to binary file
        systemBinarity    => 32,   # int    : 32 | 64
        tableSize         => 512,  # int    : table side
        verbose           => 1,    # boolean: verbosity 1-4
    );

    foreach my $key ( sort keys %defaults )
    {
        if ( ! exists $vars{$key} ) { $self->{$key} =  $defaults{$key}; } else { $self->{$key} =  $vars{$key}; };
        #print $key , " -> ", $self->{$key}, "\n";
    }

    my $function          = $vars{function};
       #$function          = \&getValues;
       #$self->{function}  = $function;
    if ( defined $function       ) { if ( $self->{verbose} > 6 ) { print "function defined\n" } } else { die "NO FUNCTION PASSED"            };
    if ( ref($function) eq 'CODE') { if ( $self->{verbose} > 6 ) { print "function is code\n" } } else { die "FUNCTION PASSED NOT A FUNCTION " . ref($function) . "\n"};
    $self->{function} = $function;

    $self->{numberRegisters} = $self->{numberRegisters} + 1; #add 1 for counter
    $systemBinarity          = $self->{systemBinarity};
    $memory                  = $self->{memory};


    my $bSize             = $self->{bitSize};
    my $numberRegisters   = $self->{numberRegisters};
    my $tableSize         = $self->{tableSize};
    my $fieldSize         = ( $bSize % 8 ) ? int(($bSize / 8)+1) : ($bSize / 8); # number of bytes per cell
    my $format1           = "BIN %".$bSize."s (%012d)\n";
    my $cellSize          = $fieldSize * $numberRegisters; # in bytes

    if ( $step > ($tableSize/5) ) { $step = int($tableSize/5); if ( $step > 1024 ) { $step = 1024 } };
    if ( ! $step ) { $step = 1; };


    print "    TABLE SIZE        : $tableSize x $tableSize (".($tableSize * $tableSize)." cells)
    REGISTERS PER CELL: $numberRegisters (".
    $tableSize                                       . " cells per line / "  .
    ($tableSize  * $numberRegisters)                 . " fields per line / " .
    (($tableSize * $tableSize) * $numberRegisters)   . " fields total)
    BYTES PER REGISTER: $fieldSize (" .
    join(" ", varSize::convertBytes(($numberRegisters * $fieldSize )))                . " per cell / " .
    join(" ", varSize::convertBytes((($tableSize * $numberRegisters) * $fieldSize ))) . " per line / " .
    join(" ", varSize::convertBytes((($tableSize * $tableSize) * $numberRegisters * $fieldSize)))." total)\n";

    my $storage        = binStorage->new(    method    => ( $memory ? 'memory' : 'disk' ),
                                             fieldSize => $fieldSize);

    $bitSize           = $bSize;
    $self->{format1}   = $format1;
    $self->{cellSize}  = $cellSize;
    $self->{fieldSize} = $fieldSize;
    $self->{storage}   = $storage;


    if ( ! ( $self->{generateArray} || $self->{loadArrayFromFile} ))
    {
        print "ARRAY MUST COME FROM SOMEWHERE. PLEASE CHECK SETTINGS\n";
        exit 1;
    }
    elsif ( ! ( $self->{saveArraytoFile} || $self->{printArray} ) && ( $memory ))
    {
        print "ARRAY MUST GO SOMEWHERE. PLEASE CHECK SETTINGS\n";
        exit 2;
    }

    if ( $self->{saveArraytoFile} && ( ! exists $self->{generateArray} ))
    {
        $self->{saveArraytoFile} = 0;
    }

    if ( $self->{printArrayToFile} && ( ! $self->{printArray} ))
    {
        $self->{printArrayToFile} = 0;
    }

    if ($self->{logToFile})
    {
        print "OPENING LOG $logFile AND REDIRECTING OUTPUT\n";
        open LOG, ">", $logFile or die "COULD NOT OPEN LOG FILE $logFile: $!";
        $std = *LOG;
    } else {
        $std = *STDOUT;
    }
    $self->{std} = $std;

    my $array;
    if ( $self->{generateArray}     )
    {
        &generateArray($self);
        $storage->saveToFile()    if ( $self->{saveArraytoFile} && $memory);
    } else {
        $storage->loadFromFile()  if ( $self->{loadArrayFromFile} && $memory );
    }

    &printArray($self)            if ( $self->{printArray}        );

    return $self;
}



sub generateArray
{
    my $self            = shift;
    my $tableSize       = $self->{tableSize};
    my $fieldSize       = $self->{fieldSize};
    my $numberRegisters = $self->{numberRegisters};
    my $verbose         = $self->{verbose};
    my $storage         = $self->{storage};
    my $std             = $self->{std};
    my $function        = $self->{function};

	print $std "#"x20 . "\n";
	print $std "GENERATING ARRAY\n";
	print $std "#"x20 . "\n";
	my $startTime = time;
	my $symArray = '';

    my ($bSize, $th)= &genTableHeader($tableSize, $numberRegisters, "header");
    print $std $th if $verbose > 3;

	for my $lineNum (0 .. $tableSize - 1)
	{
        printf $std "$bSize | ", $lineNum if $verbose > 3;
		if ( $verbose > 0 && ( ! ($lineNum % $step)) )
		{
			#printf $format1, $seqBin, $lineNum;
			my $currSize = $storage->getSize();
			print &eta($startTime, time, 0, $lineNum, $tableSize - 1, $currSize) . "\n";
		}
		#printf $format1, $seqBin, $seqNum, $revSeqBin, $revSeqNum, $bin1, $bin1Dec;

		my $lVec = '';

		foreach my $colNum (0 .. $tableSize - 1)
		{

            my ($lineStartAbs, $colStartAbs, $cellStartAbs) = &getPosition($self, $lineNum, $colNum);
            my  $values = $function->($lineNum, $colNum);

			vec($lVec, ($colNum*$numberRegisters), ($fieldSize*8)) = $count;
            printf $std "$bSize ", $count if $verbose > 3;

            for (my $p = 0; $p < @$values; $p++ )
            {
                vec($lVec, ($colNum*$numberRegisters) + $p + 1, ($fieldSize*8)) = $values->[$p];
                printf $std "$bSize ", $values->[$p] if $verbose > 3;
            }

            print $std ". " if $verbose > 3;
            $count++;
		}

        $storage->append(\$lVec);

        print $std "\n" if $verbose > 3;
	}

    $storage->flush();
}


sub getPosition
{
    my $self            = shift;
    my $tableSize       = $self->{tableSize};
    my $numberRegisters = $self->{numberRegisters};
    my $verbose         = $self->{verbose};

    my $lineNum = $_[0];
    my $colNum  = $_[1];

    my $lineStartAbs = $lineNum      *   $tableSize  * $numberRegisters;
    my $lineEndAbs   = $lineStartAbs + ( $tableSize  * $numberRegisters ) - 1;

    my $colStartRel = 0;
    my $colEndRel   = $tableSize * $numberRegisters - 1;
    my $colStartAbs = $lineStartAbs;
    my $colEndAbs   = $lineEndAbs;

    #     colA colB colC
    #row1 1xA  2xB  2xC
    #row2 2xA  2xB  2xC
    #row3 3xA  3xB  3xC

    #     colA colB colC
    #row1 1    2    3
    #row2 4    5    6
    #row3 7    8    9

    #row      |-----1-----|-----2-----|-----3-----|
    #col      |-A-|-B-|-C-|-A-|-B-|-C-|-A-|-B-|-C-|
    #cell     |-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|

    my $cellStartRel = 0;
    my $cellEndRel   = $tableSize    - 1;
    my $cellStartAbs = ( $lineNum    * $tableSize * $numberRegisters ) + ( $colNum * $numberRegisters );
    my $cellEndAbs   = $cellStartAbs + $numberRegisters - 1;

    #print "LINE $lineNum :: LINE: start $lineStartAbs end $lineEndAbs || ".
    #"COL :: REL: start $colStartRel end $colEndRel | ABS: start $colStartAbs end $colEndAbs || ".
    #"CELL $colNum :: REL: start $cellStartRel end $cellEndRel | ABS: start $cellStartAbs end $cellEndAbs\n";

    return($lineStartAbs, $colStartAbs, $cellStartAbs);
}



sub printArray
{
    my $self             = shift;
    my $numberRegisters  = $self->{numberRegisters};
    my $printArrayToFile = $self->{printArrayToFile};
    my $tableSize        = $self->{tableSize};
    my $fieldSize        = $self->{fieldSize};
    my $cellSize         = $self->{cellSize};
    my $storage          = $self->{storage};
    my $std              = $self->{std};

	print $std "#"x20 . "\n";
	print $std "PRINTING ARRAY\n";
	print $std "#"x20 . "\n";
	my $data         = $_[0];


	my $tab;
	if ( $printArrayToFile )
	{
        print "OPENING TAB $tableFile AND REDIRECTING OUTPUT\n";
		open TAB, ">$tableFile" or die "COULD NOT OPEN LOG FILE $tableFile: $!";
		$tab = *TAB;
	} else {
		$tab = *STDOUT;
	}

    my ($bSize, $th)= &genTableHeader($tableSize, $numberRegisters, "header");
    print $tab $th;

	for my $lineNum (0 .. $tableSize - 1)
	{
		printf $tab "$bSize | ", $lineNum;

		for my $colNum (0 .. $tableSize - 1)
		{
            my ($lineStartAbs, $colStartAbs, $cellStartAbs) = &getPosition($self, $lineNum, $colNum);

			my $cell = $storage->retrieve($cellStartAbs, $numberRegisters);

			#printf $std " $dSize x $dSize = $dSize [REGISTER $dSize REGISTER START $dSize REGISTER END $dSize REL CELL POS $dSize ABS CELL POS $dSize]\n", 0, 0, 0, $registerNumber, $registerStart, $registerEnd, $relColPos, $absColPos if ( ($verbose > 3) || $logToFile);

			for my $colCount (0 .. $numberRegisters - 1)
			{
				my $value = vec($$cell, $colCount, ($fieldSize*8));
				printf $tab "$bSize ", $value;
			}
			print $tab ". ";
		}
		print $tab "\n";
	}
	close TAB if $printArrayToFile;
}


sub genTableHeader
{
    my $table = $_[0];
    my $num   = $_[1];
    my $type  = $_[2];

    my $str;
    my $blockSizeLen = length(100);
    my $celLen       = $num * $blockSizeLen;
	my $bSize        = "%0".$blockSizeLen."d";

    if ( $type eq "header" )
    {
        $str .= "_"x$blockSizeLen . "_|_";
        my $sides = int((($num*$blockSizeLen) + $num - 1)/ 2) - $blockSizeLen;
        map { $str .= "_"x$sides . "_" . ($num % 2 ? "" : "_"). (sprintf($bSize, $_)) . "_" . "_"x$sides .($num % 2 ? "_" : ""). "__._" } (0 .. $table - 1);
        $str .= "\n";

        return ($bSize, $str);
    }
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



sub eta
{
	my $startT       = $_[0];
	my $currT        = $_[1];
	my $startC       = $_[2];
	my $currC        = $_[3];
	my $targetC      = $_[4];
	my $sizeCurr     = $_[5];

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
    my $cLen         = "%0" . length($targetC) . "d";

	my ($sizeCurrNum , $sizeCurrUni ) = &varSize::convertBytes($sizeCurr);
	my ($sizeEndNum  , $sizeEndUni  ) = &varSize::convertBytes($sizeEnd);
	my ($sizeUnityNum, $sizeUnityUni) = &varSize::convertBytes($sizeUnity);

	my $str          = sprintf("CURR c: $cLen :: TARGET c: $cLen ::".
							   " ELAPSED t: $elapsedTstr c: $cLen :: AVG t: %s s/c c: %.2f c/s :: LEFT t: %s c: $cLen ::".
							   " SIZE curr: $sizeCurrNum $sizeCurrUni final: $sizeEndNum $sizeEndUni [$sizeUnityNum $sizeUnityUni / unity]",
                               $currC, $targetC, $elapsedC,
							   $avgTstr, $avgC, $leftTstr, $leftC);

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
        $days = sprintf("%03d", $days);
		$sec -= $days * $cDay;
	}

	if ( $sec >= $cHour )
	{
		$hours = int($sec / $cHour );
        $hours = sprintf("%02d", $hours);
		$sec  -= $hours * $cHour;
	}

	if ( $sec >= $cMin )
	{
		$mins  = int($sec / $cMin );
        $mins  = sprintf("%02d", $mins);
		$sec  -= $mins * $cMin;
	}

	$sec = sprintf("%.0f", $sec);
    $sec = sprintf("%02d", $sec);

	my $str  = ( $days  ? $days  . "d " : '');
       $str .= ( $hours ? $hours . "h " : $days  ? "00h " : '');
       $str .= ( $mins  ? $mins  . "' " : $hours ? "00' " : '');
       $str .= ( $sec   ? $sec   . '"'  : $mins  ? '00"'  : '');
	return $str;
}


#DEPRECATED
#sub generateArray
#{
#
#    my $self            = shift;
#    my $tableSize       = $self->{tableSize};
#    my $numberRegisters = $self->{numberRegisters};
#    my $verbose         = $self->{verbose};
#
#	print "#"x20 . "\n";
#	print "GENERATING ARRAY\n";
#	print "#"x20 . "\n";
#	my $startTime = time;
#	my $symArray = '';
#
#	if ( ! $memory )
#	{
#		unlink($dataFile);
#		open MEM, ">$dataFile" or die "COULD NOT OPEN MEMORY FILE $dataFile: $!";
#		binmode(MEM);
#	}
#
#	for my $lineNum (0 .. $tableSize - 1)
#	{
#		my $seqBin    = &dec2bin($lineNum);
#		#my $revSeqBin = &rcBin($seqBin);
#		#my $revSeqNum = &bin2dec($revSeqBin);
#
#		my $bin1;
#		my $bin1Dec;
#
#		#if ($seqNum <= $revSeqNum)
#		#{
#			$bin1    = $seqBin;
#			$bin1Dec = $lineNum;
#		#} else {
#			#$bin1    = $revSeqBin;
#			#$bin1Dec = $revSeqNum;
#		#}
#
#		if ( $verbose )
#		{
#			#printf $format1, $seqBin, $lineNum;
#			my $size = &getSize(\$symArray);
#			#print &eta($startTime, time, 0, $lineNum, $tableSize - 1, \$symArray) . "\n";
#		}
#		#printf $format1, $seqBin, $seqNum, $revSeqBin, $revSeqNum, $bin1, $bin1Dec;
#
#		my $lineStartAbs = $lineNum      *   $tableSize  * $numberRegisters;
#		my $lineEndAbs   = $lineStartAbs + ( $tableSize  * $numberRegisters ) - 1;
#		my $lVec = '';
#
#		print "LINE $lineNum :: LINE: start $lineStartAbs end $lineEndAbs\n";
#
#		my $cellStartRel = 0;
#		my $cellEndRel   = $tableSize * $numberRegisters - 1;
#		my $cellStartAbs = $lineStartAbs;
#		my $cellEndAbs   = $lineEndAbs;
#		print "\tCELL :: REL: start $cellStartRel end $cellEndRel | ABS: start $cellStartAbs end $cellEndAbs\n";
#
#		foreach my $colNum (0 .. $tableSize - 1)
#		{
#			my $colBin    = &dec2bin($colNum);
#			#my $revColBin = &rcBin($colBin);
#			#my $revColNum = &bin2dec($revColBin);
#
#			my $bin2;
#			my $bin2Dec;
#
#			$bin2    = $colBin;
#			$bin2Dec = $colNum;
#
#
#			#printf "\t".$format1, $colBin, $colNum, $revColBin, $revColNum, $bin2, $bin2Dec;
#			#printf $format2, $bin1, $bin1Dec, $bin2, $bin2Dec;
#			#my $compORNum = (0+$bin1Dec | 0+$bin2Dec);
#			#my $compORBin = &dec2bin($compORNum);
#			#my $compXORNum = (0+$bin1Dec ^ 0+$bin2Dec);
#			#my $compXORBin = &dec2bin($compXORNum);
#			my $compANDDec = (0+$bin1Dec & 0+$bin2Dec);
#			my $compANDBin = &dec2bin($compANDDec);
#			#printf "\t\t$format3", $bin1, $bin1Dec, $bin2, $bin2Dec, $compANDBin, $compANDDec;
#			##print map "$_\n", ("BIN1 ".$bin1, "BIN2 ".$bin2, "AND  ".$compANDBin, "OR   ".$compORBin, "XOR  ".$compXORBin);
#			#print "\n\n";
#			#$symArray[$bin1Dec][$bin2Dec] = $compANDDec;
#
#			#     col1 col2 col3
#			#row1 1x1  2x1  2x3
#			#row2 2x1  2x2  2x3
#			#row3 3x1  3x2  3x3
#
#			#     col1 col2 col3
#			#row1 1    2    3
#			#row2 4    5    6
#			#row3 7    8    9
#
#			#row      |-----------|-----------|
#			#cell     |-----|-----|-----|-----|
#			#register |-|-|-|-|-|-|-|-|-|-|-|-|
#
#
#			my $cellNumRelStart = 0;
#			my $cellNumRelEnd   = $tableSize - 1;
#			my $cellNumAbsStart = ( $lineNum * $tableSize * $numberRegisters ) + ( $colNum * $numberRegisters );
#			my $cellNumAbsEnd   = $cellNumAbsStart + $numberRegisters - 1;
#
#			print "\t\tCELL $colNum :: REL: start $cellNumRelStart end $cellNumRelEnd | ABS: start $cellNumAbsStart end $cellNumAbsEnd\n";
#next;
#			#printf $std " $dSize x $dSize = $dSize ".
#			#"[LINE $dSize COL $dSize LINE START $dSize LINE END $dSize ".
#			#"CELL ABS NUM $dSize CELL ABS POS $dSize CEL REL POS $dSize ".
#			#"REGISTER ABS POS $dSize REGISTER REL POS $dSize] {$count}\n",
#			#$lineNum, $colNum, $lineStart, $lineEnd, $celNumAbs, $el,
#			#$compANDDec, $lineNum, $lineStart, $lineEnd, $relColPos, $absColPos if ( ($verbose > 1) || $logToFile);
#
#			#printf "    BIN1DEC $dSize [$dSize] BIN2DEC $dSize [$dSize] COMPANDDEC $dSize [$dSize] COUNT $dSize [$dSize]\n", $bin1Dec, $relColPos+0, $bin2Dec, $relColPos+1, $compANDDec, $relColPos+2, $count, $relColPos+3  if ( ($verbose > 2) || $logToFile);
#			$maxValue = $bin1Dec    > $maxValue ? $bin1Dec    : $maxValue;
#			$maxValue = $bin2Dec    > $maxValue ? $bin2Dec    : $maxValue;
#			$maxValue = $compANDDec > $maxValue ? $compANDDec : $maxValue;
#			$maxValue = $count      > $maxValue ? $count      : $maxValue;
#
#			#vec($lVec, $relRegisterNum+0, ($fieldSize*8)) = $bin1Dec;
#			#vec($lVec, $relRegisterNum+1, ($fieldSize*8)) = $bin2Dec;
#			#vec($lVec, $relRegisterNum+2, ($fieldSize*8)) = $compANDDec;
#			#vec($lVec, $relRegisterNum+3, ($fieldSize*8)) = $count++;
#		}
#
#		if ( $memory )
#		{
#			$symArray .= $lVec;
#		} else {
#			use bytes;
#			#print "ADDING ". &getSize(\$lVec) ." TO FH AT POS " . (($registerStart*$fieldSize)+$fieldSize) . ". NEXT ".(&getSizeBytes(\$lVec)+($registerStart*$fieldSize))."\n";
#			#seek  MEM, (($registerStart*$fieldSize)+$fieldSize), 0 or die "COULD NOT SEEK: $!";
#			print MEM  $lVec;
#		}
#	}
#
#	if ( ! defined $symArray )
#	{
#		die "ERROR GENERATING ARRAY";
#	} else {
#		print "TOTAL $count\n";
#	}
#
#	if ( ! $memory )
#	{
#		close MEM;
#	}
#
#	return \$symArray;
#}


1;
