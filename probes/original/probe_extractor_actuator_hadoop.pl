#!/usr/bin/perl -w
# Saulo Aflitos
# 2009 06 18 19 47
use strict;
use warnings;

#############################################
######## USAGE DECLARATIONS
#############################################
use File::Copy;
use Devel::Size qw(size total_size);
use List::Util qw[min max];
use threads;
use threads::shared;
use threads 'exit'=>'threads_only';

use lib "./filters";
use loadconf;
use toolsOO;
my %pref  = &loadconf::loadConf;
my $tools = toolsOO->new();;

#############################################
######## SETUP
#############################################
&loadconf::checkNeeds(
"actuatorDelete",	"log",				"maxThreads",	"napTime",
"verbose",			"max_packet_size",	"exportSeq",	"database",
"outDir",			"dumpDir",			"sqlDir", 		"probeExtFunc");

#SPLITTER
my $log          = $pref{"log"}; #HOW VERBOSY
my $maxThreads   = $pref{"maxThreads"};
my $napTime      = $pref{"napTime"}; # time between each attempt to start a new thread if the number of threads exceeed maxtreads
my $outDir       = $pref{"outDir"};
my $dumpDir      = $pref{"dumpDir"};
my $sqlDir       = $pref{"sqlDir"};

#ACTUATOR
my $actuatorDelete  = $pref{"actuatorDelete"};

my $verbose         = $pref{"verbose"};
my $max_packet_size = $pref{"max_packet_size"};	# max_insertion_size in mysql configuration (in bytes)

my $exportSQL       = $pref{"exportSQL"};
my $exportTAB       = $pref{"exportTAB"};
my $exportHAD       = $pref{"exportHAD"};
my $exportSeq       = $pref{"exportSeq"};
my $probeExtFuncN   = $pref{"probeExtFunc"};

#SPLITTER GLOBALS
my $runned = 0;
my %idKey;
my @idKeyRev;
my @seqKeyRev ;
my $totalSeq  ;
my $totalFrag ;
my $progTotalBp;


#ACTUATOR GLOBALS
my $centimo     = 0;
my $countValAll = 0;
my %inputHash;
my %sqlCodes;

#############################################
######## LOGIC
#############################################
`sudo renice -10 $$`;

my $function     = $ARGV[0];
if (( defined $function ) && ( $function eq "ACTUATOR" ))
{
	print "EXTRACTOR: ACTUATOR\n";
	&actuator(@ARGV);
}
else
{
	print "EXTRACTOR: SPLITTER\n";
	&splitter(@ARGV);
}



#############################################
######## PROGRAM
#############################################
sub actuator
{
	my $inputFile = $_[1];

	if ( ! ( $ARGV[1] ) )
	{
		print "USAGE: $0 ACTUATOR </full/path/to/dump/file>\n";
		print "   </full/path/to/dump/file> full path to xml dump file\n";
		print "EXAMPLE:\n";
		print "   $0 ACTUATOR /mnt/ssd/probes/dumps/Cryptococcus_gattii_WM276_GENES.fasta_1.xml\n\n";
		exit(1);
	};

	if ( ! ( -f $inputFile ) ) { die "DIED: INPUT  FILE $inputFile   DOESNT EXISTS: $!" };

	&loadXML(\%inputHash, $inputFile);

	my $outDir        = $inputHash{"outDir"};
	my $sqlDir        = $inputHash{"sqlDir"};
	my $dumpDir       = $inputHash{"dumpDir"};

	my $fastaFile     = $inputHash{"fastaFile"};
	my $fullFastaFile = $inputHash{"fullFastaFile"};
	my $taxonID       = $inputHash{"taxonID"};
	my $variant		  = $inputHash{"variant"};
	my $sequenceType  = $inputHash{"sequenceType"};

	my $ac_file       = $inputHash{"MKFfile"};
	my $ac_id         = $inputHash{"MKFID"};
	my $ac_id_short   = $inputHash{"id_short"};
	my $ac_id_long    = $inputHash{"id_long"};
	my $ac_sequence   = $inputHash{"sequence"};

	if (0)
	{
		foreach my $key (keys %inputHash)
		{
			print "\t$key > $inputHash{$key}\n";
		}
	}

	if ( ! ( -f $fullFastaFile ) ) { die "DIED: FASTA  FILE $fullFastaFile DOESNT EXISTS: $!"};
	if ( ! ( -d $outDir        ) ) { mkdir ($outDir)  or die "DIED: OUTPUT DIR  $outDir  DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
	if ( ! ( -d $sqlDir        ) ) { mkdir ($sqlDir)  or die "DIED: SQL    DIR  $sqlDir  DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
	if ( ! ( -d $dumpDir       ) ) { mkdir ($dumpDir) or die "DIED: DUMP   DIR  $dumpDir DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };


	my $probeExtFunc;
	if (defined $probeExtFuncN )
	{
		#similarity1_quasiblast::sthAnalizeSimilarity1
		my $func;
		my $use;
		my @package = split("::",$probeExtFuncN);
		my $uStr = 'use filters::' .  $package[0];
		eval $uStr;
		die "ERROR EVALUATING USAGE :: $probeExtFuncN PACKAGE $package[0] == $uStr : $@" if $@;


		#my $mlpa = mlpaOO->new(\%pref);
		my $nStr = '$func = ' . $probeExtFuncN . "->new(\\%pref)";
		eval $nStr;
		die "ERROR EVALUATING NEW :: $probeExtFuncN == $nStr : $@" if $@;

		#my $fStr = '$func = \&' . "$probeExtFuncN";
		#eval $fStr;
		#die "ERROR EVALUATING $probeExtFuncN == $fStr : $@" if $@;

		print "\tLOADING DINAMIC MODULE : $probeExtFuncN ... DONE\n";
		$probeExtFunc = $func;
	}
	else
	{
		die "NO EXTRACTOR DEFINED\n";
	}


	####################################################
	####### SQL STATEMENTS
	####################################################
	#use DBI;
	#use DBD::mysql;

	#my $host      = 'localhost';
	#my $user      = 'probe';
	#my $pw        = '';
	# probe  1.22
	# probe2 1.19
	#my $SQLinsertOrganism    = "INSERT IGNORE INTO organism     (nameOrganism, taxonId, variant, sequenceTypeId)                                  VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE idorganism=LAST_INSERT_ID(idorganism), count=count+1";
	#my $SQLinsertChromossome = "INSERT IGNORE INTO chromossomes (idOrganism, chromossomeNumber, chromossomeShortName, chromossomeLongName)        VALUES (?, ?, ?,?)  ON DUPLICATE KEY UPDATE chromossomes.chromossomeNumber=chromossomes.chromossomeNumber";
	#my $SQLinsertProbe       = "INSERT IGNORE INTO probe        (sequenceLig, sequenceM13, probeGc, probeTm)                                      VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE idprobe=LAST_INSERT_ID(idprobe)      , count=count+1";
	#my $SQLinsertCoord1      = "INSERT IGNORE INTO coordinates  (idOrganism, idProbe, startLig, startM13, endM13, strand, chromossome, derivated) VALUES ";
	#my $SQLinsertCoord2      = " ON DUPLICATE KEY UPDATE idcoordinates=LAST_INSERT_ID(idCoordinates), count=count+1";
	##my $SQLinsertComplete   = "INSERT INTO complete  (idOrganism, sequenceLig, sequenceM13, probeGc, probeTm, startLig, startM13, endM13, strand, sequence, ligant, chromossome, derivated, count)  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)";
	#TODO: SOFTCODE
	my $database  = $pref{"database"};
	my $SQLinsertComplete1   = "INSERT INTO `$database`.`complete`  (idOrganism, startLig, startM13, endM13, strand, chromossome, derivated, sequenceLig, sequenceLigGc, sequenceLigTm, sequenceM13, sequenceM13Gc, sequenceM13Tm, sequence, sequenceGc, sequenceTm, ligant)  VALUES ";

		$sqlCodes{"organism"}[0]    = "$sqlDir/organism";
		$sqlCodes{"organism"}[1]    = "INSERT IGNORE INTO `$database`.`organism` (idorganism, nameOrganism, taxonId, variant, sequenceTypeId) VALUES";
		$sqlCodes{"organism"}[2]    = "ON DUPLICATE KEY UPDATE idorganism=LAST_INSERT_ID(idorganism), count=count+1";

		$sqlCodes{"chromossome"}[0] = "$sqlDir/chromossome";
		$sqlCodes{"chromossome"}[1] = "INSERT IGNORE INTO `$database`.`chromossomes` (idOrganism, chromossomeNumber, chromossomeShortName, chromossomeLongName)        VALUES";
		$sqlCodes{"chromossome"}[2] = "ON DUPLICATE KEY UPDATE chromossomes.chromossomeNumber=chromossomes.chromossomeNumber";


	#############################################
	######## INITIATION
	#############################################

	my $progTotalBp   = 0;

	#	unlink("log.txt");

	&printLog(1, "RUNNING OVER FILE $fullFastaFile BY $inputFile\n");

	&printLog(1, "MAKING FRAGMENTS FOR $ac_file " . $ac_id_long . "[$ac_id] (" . length($ac_sequence) . "bp)\n");

	&mkFragmentsAC($ac_file, $ac_id, $ac_sequence, $ac_id_short, $ac_id_long,
				   $taxonID, $variant, $fastaFile, $sequenceType, $SQLinsertComplete1, $probeExtFunc);

	if ($runned)
	{
		&printLog(1,	"FILE $fullFastaFile BY $inputFile ANALIZED");

		if ($actuatorDelete == 1)
		{
			unlink($inputFile) or die "DIED: COULD NOT DELETE $inputFile: $!";
		}
		elsif ($actuatorDelete == 0)
		{
			my $newFile = $inputFile;
			$newFile    =~ s/.xml$/.znm/;
			move($inputFile, $newFile);
		}
	}
	else
	{
		die "DIED: A PROBLEM WAS FOUND WHILE RUNNING $fullFastaFile BY $inputFile. PLEASE CHECK YOUR FASTA FILE";
	}
	undef @seqKeyRev;
	undef %idKey;
	undef @idKeyRev;
	undef $totalSeq;
	undef $totalFrag;
}














sub splitter
{
	my $indir        = $_[0];
	my $fastaFile    = $_[1];
	my $taxonID      = $_[2];
	my $variant		 = $_[3];
	my $sequenceType = $_[4];


	#############################################
	######## CHECKINGS AND DECLARATIONS
	#############################################


	if ( @ARGV < 4)
	{
		print "USAGE: $0 </full/path/input/dir> <fastaFile> <NCBI_taxon_id> <variant> <sequence_type>\n";
		print "EXPLANATION\n",
		"  <input dir>     : full path to directory containing fasta file","\n",
		"  <fasta file>    : fasta file name","\n",
		"  <NCBI_taxon_id> : ncbi species code,","\n",
		"  <variant>       : incremental number used to subspecies","\n",
		"  <sequence_type> :        CDS          1","\n",
		"                           CHROMOSSOMES 2","\n",
		"                           CIRCULAR     3","\n",
		"                           CONTIGS      4","\n",
		"                           COMPLETE     5","\n",
		"                           GENES        6","\n",
		"                           ORF          7","\n",
		"                           PARTIAL      8","\n",
		"                           WGS SCAFFOLD 9","\n",
		"EXAMPLE\n",
		"  $0 /var/rolf/input Cryptococcus_gattii_WM276_GENES.fasta 552467 1 6",
		"\n";
		exit(1);
	};

	my $inputFile;

	my $fullFastaFile = "$indir/$fastaFile";
	if ( ! ( -d $indir         ) ) { die "INPUT  DIR  $indir         DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
	if ( ! ( -f $fullFastaFile ) ) { die "INPUT  FILE $fullFastaFile DOESNT EXISTS: $!"};
	if ( ! ( -d $outDir        ) ) { mkdir ($outDir)  or die "OUTPUT DIR  $outDir  DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
	if ( ! ( -d $sqlDir        ) ) { mkdir ($sqlDir)  or die "SQL    DIR  $sqlDir  DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
	if ( ! ( -d $dumpDir       ) ) { mkdir ($dumpDir) or die "DUMP   DIR  $dumpDir DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };


	#############################################
	######## INITIATION
	#############################################
	my $progStartTime = time;
	my $progTotalBp   = 0;

	unlink("log.txt");
	if ($log >=0)
	{
		open  LOG, ">log" or die "COULD NOT SAVE LOG: $!";
	}

	&printLog(0, "RUNNING OVER FILE $fullFastaFile\n");

	my %vars;
	$vars{"fastaFile"}     = $fastaFile;
	$vars{"fullFastaFile"} = $fullFastaFile;
	$vars{"taxonID"}       = $taxonID;
	$vars{"variant"}       = $variant;
	$vars{"sequenceType"}  = $sequenceType;
	$vars{"outDir"}        = $outDir;
	$vars{"dumpDir"}       = $dumpDir;
	$vars{"sqlDir"}        = $sqlDir;

	&getFasta($fullFastaFile, \%vars);

	foreach my $thr (threads->list)
	{
		if ($thr->tid && !threads::equal($thr, threads->self))
		{
			while ($thr->is_running())
			{
				sleep($napTime);
			}
		}
	}

	foreach my $thr (threads->list)
	{
		while ($thr->is_running())
		{
			sleep($napTime);
		}
	}

	foreach my $thr (threads->list(threads::joinable))
	{
		$thr->join();
	}

	if ($runned)
	{
		&printLog(0,	"$totalSeq SEQUENCES ON FILE $fullFastaFile");
		&printLog(0,	"$progTotalBp bp on " . (time - $progStartTime) . " s [ " . (int(($progTotalBp/(time - $progStartTime))+.5)) . " bp/s ]\n");
	}
	else
	{
		die "A PROBLEM WAS FOUND WHILE RUNNING. PLEASE CHECK YOUR FASTA FILE";
	}

	close LOG;
}






#*******************************************************************************
#*******************************************************************************
#*******************************************************************************
#*******************************************************************************
#******************************** LIBRARIES ************************************
#*******************************************************************************
#*******************************************************************************
#*******************************************************************************
#*******************************************************************************

################################################################################
################################################################################
################################################################################
################################ SPPLITTER #####################################
################################################################################
################################################################################
################################################################################

#############################################
######## FUNCTIONS
#############################################

sub mkFragments
{
	my $MKFfile  = $_[0];
	my $MKFID    = $_[1];
	my $sequence = uc($_[2]);

	my %lVars 	 = %{$_[3]};

	my $id_short       = $idKeyRev[$MKFID][0];
	my $id_long        = $idKeyRev[$MKFID][1];

	$lVars{"MKFfile"}  = $MKFfile;
	$lVars{"MKFID"}    = $MKFID;
	$lVars{"id_short"} = $id_short;
	$lVars{"id_long"}  = $id_long;
	$lVars{"sequence"} = $sequence;

	my $dumpDir   = $lVars{"dumpDir"};
	my $fastaFile = $lVars{"fastaFile"};

	my $outName = "$dumpDir/$fastaFile\_" . $tools->zerofy($MKFID, 4) . ".xml";
	saveXML(\%lVars, $outName);
	%lVars=();
#	print system("./probe_extractor_actuator.pl $outName");
#	print "$outName\n\n\n";
	if ( -f $outName )
	{
		#my $response = "";#`./probe_extractor_actuator.pl $outName 2>&1`;
		#if ( $response =~ /DIED/igm )
		#{
		#	&printLog(0, $response);
		#	die "ACTUATOR ERROR > \n$fastaFile :: $outName";
		#}
		#else
		#{
		#	&printLog(1, $response);
		#	&printLog(0, "ACTUATOR OK > $fastaFile :: $outName\n");
		#}
	}
	else
	{
		die "COULD NOT SAVE DUMP FILE $outName";
	}

	return undef;
}


sub getFasta
{
	my $file  = $_[0];
	my $vars  = $_[1];

	my $fastaFile = $vars->{"fastaFile"};

	my @seq;
	my @tmpSeq;
	my $count = 0;
	my $ID;
	my $sequence;
	my @threads;

	open FILE, "<$file" or die "COULD NOT OPEN FASTA FILE $file: $!\n";
	while (my $line = <FILE>)
	{
		chomp $line;
		$count++;
		if ($line)
		{
			if (substr($line,0,1) eq '>')
			{
				if ((defined $ID) && ($sequence))
				{
					while (threads->list(threads::running) > ($maxThreads-1))
					{
						sleep($napTime);
					}

					foreach my $thr (threads->list(threads::joinable))
					{
						$thr->join();
					}

					$progTotalBp += length($sequence);
					&printLog(0, "EXPORTING DUMP FOR $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
					threads->new(\&mkFragments, ($fastaFile, $ID, $sequence, $vars));
					$totalSeq++;
				}

				$ID     = substr($line, 1);
				$line   = substr($line, 1);

				#if ($ID =~ /(\S+)\s/) {$ID = $1;};
				$ID =~ tr/ /_/;
				$ID =~ tr/\//_/;
				$ID =~ tr/a-zA-Z0-9_/_/cd;

				if ( ! defined $idKey{$ID})
				{
					my $key            = @idKeyRev;
					$idKey{$ID}        = $key;
					$idKeyRev[$key][0] = $ID;
					$idKeyRev[$key][1] = $line;
					$ID = $key;
				}


				$sequence = "";
			} # end if ^>
			else
			{
				$line = uc($line);
				$line =~ tr/[A|C|T|G|N]/N/cd;
				if ($line =~ /[^ACTGN]/){ die "STRANGE CHARACTER IN FASTA: $line";};

				#$line =~ tr/[A|C|T|G|N|a|c|t|g|n]//cd;

# 				print "$_\n";
				if ((defined $ID) && ($ID ne "") && ($ID ne " "))
				{
					$sequence .= $line;
				}
				else
				{

				}
			} # end if else ^>
		} #end if $_
	} # end while file

	if ((defined $ID) && ($sequence))
	{
		while (threads->list(threads::running) > ($maxThreads-1))
		{
			sleep($napTime);
		}

		foreach my $thr (threads->list(threads::joinable))
		{
			$thr->join();
		}

		$progTotalBp += length($sequence);
		&printLog(0, "EXPORTING DUMP FROM $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
		threads->new(\&mkFragments, ($fastaFile, $ID, $sequence, $vars));
		$totalSeq++;
	}
	close FILE;

	$runned = 1;

	&printLog(0, "$count LINES LOADED FOR $file\n");
}


# CHECK REVERSE - DO NOT DELETE
#my $m  = substr($MKFsequence, $ligStart-1, ($ligLen+$m13Len));
#my $o  = reverse($sequence);
#   $o  =~ tr/ACTG/TGAC/;
#my $oo = substr($o, $ligStart-1, ($ligLen+$m13Len));
#my $on = substr($o, $m13EndF , ($ligLen+$m13Len));
#   $on =~ tr/ACTG/TGAC/;
#   $on = reverse($on);
#my $on = substr($o, $m13EndF-1 , ($ligLen+$m13Len));
#   $on =~ tr/ACTG/TGAC/;
#   $on = reverse($on);

#my $TmpMKFsequence = $sequence;
   #$TmpMKFsequence =~ tr/ACTG/TGAC/;
#print "ORIGINAL   : $ligStart\t$m13Start\t$m13End\n";
#print "NEW        : $ligStartF\t$m13StartF\t$m13EndF\n";
#print "LENGTH     : " . length($sequence) . "/" . $MKFsequenceLength . "\n";
#print "ALLSEQ     : " . " "x10 . " $ligStart $MKFligSeq-$MKFm13Seq $m13End ($ligStart $ligLen $m13Start $m13Len)\n";

#print "EXTRACTEDm : " . " $ligStart " . substr($MKFsequence, 0, 5) . " ... " . $m  . " ... " . substr($MKFsequence, -5, 5) . " $m13End\n";
#print "EXTRACTEDoo: " . substr($o          , 0, 5) . " ... " . $oo . " ... " . substr($o          , -5, 5) . "\n";
#print "EXTRACTEDon: " . " $ligStartF " . substr($o          , 0, 5) . " ... " . $on . " ... " . substr($o          , -5, 5) . " $m13EndF [$m13StartF]\n\n\n";
#die;
#print "$MKFallSeq, $allGC, $allTm, $ligStartF, $m13StartF, $m13EndF\n";


#############################################
######## TOOLKIT
#############################################
sub printLog
{
	my $verbo = $_[0];
	my $text  = $_[1];
	my $lTime = time;
	print "\t", $lTime , "\tEXTRACTOR: ", $text if ( $verbo <= $log );

	if ($verbo <= $log)
	{
		print LOG $lTime , "\tEXTRACTOR: ", $text;
	}
}







################################################################################
################################################################################
################################################################################
################################ ACTUATOR ######################################
################################################################################
################################################################################
################################################################################

#############################################
######## FUNCTIONS
#############################################

sub mkFragmentsAC
{
	my $MKFfile            = $_[0];
	my $MKFID              = $_[1];
	my $sequence           = uc($_[2]);
	my $chromShort         = $_[3];
	my $chromLong          = $_[4];

	my $taxonID            = $_[5];
	my $variant            = $_[6];
	my $fastaFile          = $_[7];
	my $sequenceType       = $_[8];
	my $SQLinsertComplete1 = $_[9];
	my $probeExtFunc       = $_[10];

	my $revC       = 0;
	my $rev;

	#sequence $sequence

	print "
	MKFfile      $MKFfile
	MKFID        $MKFID
	chromShort   $chromShort
	chromLong    $chromLong
	taxonID      $taxonID
	variant      $variant
	fastaFile    $fastaFile
	sequenceType $sequenceType
	SQL          $SQLinsertComplete1
	";

	my $orgId    = "$taxonID.$variant";
	$0 = "$0 :: $MKFfile : $MKFID : $taxonID : $variant";

	if ($exportSQL)
	{
		&printInsert("organism", undef, $MKFID, $orgId,     $fastaFile,   $taxonID, $variant, $sequenceType);
		if ($verbose) { &printLogAC(2, "INSERTING ORGANISM:, ". $fastaFile. " > ". $orgId . "\n") };

		&printInsert("chromossome", undef, $MKFID, $orgId,    ($MKFID+1),         $chromShort,          $chromLong);
		if ($verbose) { &printLogAC(2, "INSERTING CHROMOSSOME: ". $fastaFile. " > ". ($MKFID+1) . " " . $chromLong . "\n") };
	}

	my $MKFsequenceLength = length($sequence);

	   $countValAll        = 0;
	my $beforeGeneral      = time;
	my $beforeProbeGeneral = 0;
	my $name               = $probeExtFunc->getName();

	if ($exportSeq)
	{
		for my $MKFsequence ($sequence, $sequence)
		{
			my $strand = "F";
			if ( $revC )
			{
				$strand = "R";
				$rev    = " REV";
				$MKFsequence = reverse($MKFsequence);
				$MKFsequence =~ tr/ACGT/TGCA/;
			}
			else
			{
				$strand = "F";
				$rev    = " FWD";
			};

			print "GOING $rev\n";

			my @probe;
			my $ite;
			my $lCountValAll;
			my $maxLen;


			#my $mlpa = mlpaOO->new(\%pref);
			#($ite, $lCountValAll, $centimo, $maxLen) = $mlpa->act(\@probe, $MKFsequence, $revC);

			($ite, $lCountValAll, $centimo, $maxLen) = $probeExtFunc->act(\@probe, $MKFsequence, 0, $revC);
			$countValAll += $lCountValAll;

			#######################
			#### ACTUAL QUERIES
			#######################
			my $probeSize      = @probe;

			print "PROBE SIZE = $probeSize\n";

			if ($probeSize)
			{
				my $probeSizeBytes = size(\@probe);
				my $middle         = (int(($maxLen / 2)+.5)); # average size of probe size
				my $before         = time;
				my $lastPos        = -300;
				my $nextDev        = -300;

				my $sqlLine;
				my $countValues   = 1;
				my $sqlLinesCount = 1;
				my $sqlLineSize   = 0;
				my $SQLfile       = "$sqlDir/$MKFfile." . $tools->zerofy($MKFID, 4) . "." . $tools->zerofy($countValues, 3) . ".$strand.$name.sql";
				my $TABfile       = "$sqlDir/$MKFfile." . $tools->zerofy($MKFID, 4) . "." . $tools->zerofy($countValues, 3) . ".$strand.$name.tab";
				my $HADfile       = "$sqlDir/$MKFfile." . $tools->zerofy($MKFID, 4) . "." . $tools->zerofy($countValues, 3) . ".$strand.$name.had";

				my $SQLFILEFH;

				if ($exportSQL)
				{
					&printLogAC(0, "\t\tEXPORTING SQL FILE $SQLfile\n");
					open  ($SQLFILEFH, ">$SQLfile") or die "DIED: COULD NOT OPEN SQLFILE $SQLfile";
					print $SQLFILEFH $SQLinsertComplete1;
				}

				if ($exportTAB)
				{
					&printLogAC(0, "\t\tEXPORTING TAB FILE $TABfile\n");
					open  TABFILE, ">$TABfile" or die "DIED: COULD NOT OPEN SQLFILE $TABfile";
				}

				if ($exportHAD)
				{
					&printLogAC(0, "\t\tEXPORTING HAD FILE $HADfile\n");
					open  HADFILE, ">$HADfile" or die "DIED: COULD NOT OPEN SQLFILE $HADfile";
				}

				while (my $localProbe = shift @probe)
				{

					my $derivated  = 0;
					my $strand     = ${$localProbe}[0];
					my $start      = ${$localProbe}[1];

					if ($strand eq "R")
					{
						if ($lastPos == -300) { $lastPos = $start - ($middle * -1) -1; };
						if ($nextDev == -300) { $nextDev = $start - $middle; };
						if ((($lastPos-$middle) <= $start) && ($lastPos >= $nextDev))
						{
							$derivated = 1;
						}
						else
						{
							$nextDev   = $start-$middle;
						}
					} # end if reverse
					else
					{
						if ($lastPos == -300) { $lastPos = $start + ($middle * -1) -1; };
						if ($nextDev == -300) { $nextDev = $start + $middle; };
						if ((($lastPos+$middle) >= $start) && ($lastPos <= $nextDev))
						{
							$derivated = 1;
						}
						else
						{
							$nextDev   = $start+$middle;
						}
					} # end if forward

					$lastPos = $start;

					if ($exportSQL)
					{
						if ($sqlLinesCount) { print SQLFILE ", "; };
						$sqlLine       = $probeExtFunc->toSql($orgId, ($MKFID+1), $derivated, $localProbe);
						$sqlLineSize  += size(\$sqlLine);
						$sqlLinesCount++;

						print SQLFILE $sqlLine;

						if ($sqlLineSize >= $max_packet_size * 0.975)
						{
							$countValues++;
							$sqlLinesCount = 0;
							print $SQLFILEFH ";", "\n";
							close $SQLFILEFH;

							$SQLfile = "$sqlDir/$MKFfile." . $tools->zerofy($MKFID, 4) . "." . $tools->zerofy($countValues, 3) . ".$strand.$name.sql";

							open  ($SQLFILEFH, ">$SQLfile") or die "DIED: COULD NOT OPEN SQLFILE $SQLfile";
							print $SQLFILEFH $SQLinsertComplete1;

						};
					}

					if ($exportTAB)
					{
						print TABFILE $probeExtFunc->toTab($orgId, ($MKFID+1), $derivated, $localProbe);
					}

					if ($exportHAD)
					{
						print HADFILE $probeExtFunc->toHad($orgId, ($MKFID+1), $derivated, $localProbe);
					}
				} #end while my local probe

				if ($exportSQL)	{ print $SQLFILEFH ";", "\n"; close $SQLFILEFH; };
				if ($exportTAB) { close TABFILE; };
				if ($exportHAD) { close HADFILE; };

				@probe = ();
	#				my $insertComplete = $dbh->prepare_cached("$SQLinsertComplete1$value" ) or print "COULD NOT PREPARE COMPLETE QUERY: " . $DBI::errstr;
	#				   $insertComplete->execute() or print "COULD NOT EXECUTE COMPLETE QUERY: " . $idKeyRev[$MKFID][1] . " " . $DBI::errstr . "\n";

	#				my $working = 1;
	#				my $crashed = 0;

	#				while ($working)
	#				{
	#					if ( ! (defined $DBI::errstr) )
	#					{
	#						$insertComplete->finish();
	#						$working = 0;
	#					}
	#					elsif ((defined $DBI::err) && ($DBI::err == 1213))
	#					{
	#						sleep($napTime);
	#						$insertComplete->execute() or print "COULD NOT EXECUTE COMPLETE QUERY: " . $idKeyRev[$MKFID][1] . " " . $DBI::errstr . "\n";
	#						$crashed = 1;
	#					}
	#					else
	#					{
	#						die "DIED: COULD NOT EXECUTE PROBE QUERY: " . $DBI::errstr . "\n";
	#					}
	#				}

	#				while ( ! ($dbh->commit()))
	#				{
	#					print "commit failed. trying again\n";
	#				}

				my $probeElapsed     = time - $before;
				$beforeProbeGeneral += $probeElapsed;
				my $pbs = $probeElapsed ? int($probeSize / ($probeElapsed)) : $probeSize;
				&printLogAC(1,  "\t\t". $probeSize. " PROBES INSERTED IN ". $probeElapsed. " s (". $pbs. " probes/s) FOR " . $taxonID . $rev. "\n");
			} #end if probe
			else
			{
				&printLogAC(1, "NO PROBES FOUND AFTER $ite ITERATIONS\n");
			}
			$revC++;
		} # end foreach my $sequence revComp(sequence)
	}

	my $elapsed      = time-$beforeGeneral;
	my $elapsedProbe = $beforeProbeGeneral;
	my $pbs  = $elapsed      ? int($countValAll       / $elapsed)      : $countValAll;
	my $mbs  = $elapsed      ? int($MKFsequenceLength / $elapsed)      : $MKFsequenceLength;
	my $pIbs = $elapsedProbe ? int($countValAll       / $elapsedProbe) : $countValAll;
	&printLogAC(1, "\tSEQUENCE ". $MKFfile. " "  . $taxonID . " ANALIZED IN ". $elapsed. " s\n" .
	      "\t\t" . $countValAll.       " PROBES GENERATED (".           $pbs. " probes/s)\n" .
	      "\t\t" . $countValAll.       " PROBES INSERTS GENERATED IN ". $elapsedProbe. " s (". $pIbs. " probes inserts/s)\n" .
	      "\t\t" . $MKFsequenceLength. " BP ANALYSED (".                $mbs. " bp/s)\n\n");

	#$dbh->commit();
	#$dbh->disconnect();

	$runned = 1;
	return undef;
}





sub printInsert
{
	my $code  = $_[0];
	my $file  = $_[1];
	my $ac_id = $_[2];
	my @data  = @_[3 .. (@_-1)];

	if (exists $sqlCodes{$code})
	{
		if (defined ${$sqlCodes{$code}}[0])
		{
			$file = ${$sqlCodes{$code}}[0] .  "."  .$data[0] . "." . $tools->zerofy($ac_id,3) . ".sql";
		}
		elsif (defined $file)
		{
			$file = $file;
		}
		else
		{
			die "NO FILE DEFINED";
		}

		open FILE, ">>$file" or die "DIED: COULD NOT OPEN SQLFILE $file";
		print FILE $sqlCodes{$code}[1], " (\"", join("\",\"",@data), "\")";
		if (defined $sqlCodes{$code}[2])
		{
			print FILE " ", $sqlCodes{$code}[2], " ";
		}
		print FILE ";\n";
		close FILE;

	}
	else
	{
		die "NO SQL CODE FOUND FOR $code";
	}
}





sub cleanCodes
{
	foreach my $key (keys %sqlCodes)
	{
		my $file = $sqlCodes{$key}[0];
		if ( -f $file )
		{
			unlink($file);
		}
	}
}


# CHECK REVERSE - DO NOT DELETE
#my $m  = substr($MKFsequence, $ligStart-1, ($ligLen+$m13Len));
#my $o  = reverse($sequence);
#   $o  =~ tr/ACTG/TGAC/;
#my $oo = substr($o, $ligStart-1, ($ligLen+$m13Len));
#my $on = substr($o, $m13EndF , ($ligLen+$m13Len));
#   $on =~ tr/ACTG/TGAC/;
#   $on = reverse($on);
#my $on = substr($o, $m13EndF-1 , ($ligLen+$m13Len));
#   $on =~ tr/ACTG/TGAC/;
#   $on = reverse($on);

#my $TmpMKFsequence = $sequence;
   #$TmpMKFsequence =~ tr/ACTG/TGAC/;
#print "ORIGINAL   : $ligStart\t$m13Start\t$m13End\n";
#print "NEW        : $ligStartF\t$m13StartF\t$m13EndF\n";
#print "LENGTH     : " . length($sequence) . "/" . $MKFsequenceLength . "\n";
#print "ALLSEQ     : " . " "x10 . " $ligStart $MKFligSeq-$MKFm13Seq $m13End ($ligStart $ligLen $m13Start $m13Len)\n";

#print "EXTRACTEDm : " . " $ligStart " . substr($MKFsequence, 0, 5) . " ... " . $m  . " ... " . substr($MKFsequence, -5, 5) . " $m13End\n";
#print "EXTRACTEDoo: " . substr($o          , 0, 5) . " ... " . $oo . " ... " . substr($o          , -5, 5) . "\n";
#print "EXTRACTEDon: " . " $ligStartF " . substr($o          , 0, 5) . " ... " . $on . " ... " . substr($o          , -5, 5) . " $m13EndF [$m13StartF]\n\n\n";
#die;
#print "$MKFallSeq, $allGC, $allTm, $ligStartF, $m13StartF, $m13EndF\n";


#############################################
######## TOOLKIT
#############################################



sub printLogAC
{
	my $verbo = $_[0];
	my $text  = $_[1];
	my $lTime = time;

	print "\t", $lTime , "\tACTUATOR: ", $text if ( $verbo <= $log );

	if ($verbo <= $log)
	{
		if ($log >=0)
		{
			open  LOG, ">>actuator_log" or die "DIED: COULD NOT SAVE LOG: $!";
			print LOG $lTime , "\tACTUATOR: ", $text;
			close LOG;
		}

	}
}




#############################################
######## SHARED
#############################################
sub saveXML
{
    my $ref  = $_[0];
    my $file = $_[1];

    if (ref($ref) eq "HASH")
    {
		open DUMPXML, ">$file" or die "COULD NOT SAVE DUMPXML $file: $!";

		print DUMPXML "<xml>\n";
		foreach my $key (sort keys %{$ref})
		{
			my $value = $ref->{$key};
			$value    =~ tr/\n//;
			$value    =~ tr/\r//;
			print DUMPXML "\t<", $key, ">",$value,"</", $key, ">\n";
		}
		print DUMPXML "</xml>\n";
		close DUMPXML;
    }
	else
	{
		die "NOT A HASH REFERENCE";
	}
}


sub loadXML
{
	my $ref  = $_[0];
	my $file = $_[1];

    if (ref($ref) eq "HASH")
    {
		open DUMPXML, "<$file" or die "COULD NOT OPEN DUMPXML $file: $!";
		my $start = 0;
		while (my $line = <DUMPXML>)
		{
			chomp $line;
			if ($line eq "</xml>") { $start = 0; }

			if ($start)
			{
				if ($line =~ /<(.*)>(.*)<\/\1>/)
				{
					#print "$1: $2\n";
					$ref->{$1} = $2;
					if ( ! defined $ref->{$1})
					{
						die "COULD NOT EXTRACT INFORMATION FROM XML FILE: $line";
					}
				}
				else
				{
					print "UNKNOWN LINE FORMAT: $line\n";
					die;
				}
			}

			if ($line eq "<xml>")  { $start = 1; }
		}
		close DUMPXML;
	}
	else
	{
		die "NOT A HASH REFERENCE";
	}
}


1;
