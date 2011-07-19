#!/usr/bin/perl -w
# Saulo Aflitos
# 2009 06 18 19 47
use strict;
use warnings;

#############################################
######## USAGE DECLARATIONS
#############################################
use Storable;
use Data::Dumper;

use Devel::Size qw(size total_size);
use lib "./filters";
use dnaCode;
use loadconf;
use mlpaOO;
my %pref = &loadconf::loadConf;

use List::Util qw[min max];
use threads;
use threads::shared;
use threads 'exit'=>'threads_only';

#############################################
######## SETUP
#############################################
&loadconf::checkNeeds(
"actuatorDelete",	"log",				"maxThreads",	"napTime",
"verbose",			"max_packet_size",	"exportSeq",	"database",
"outDir",			"dumpDir",			"sqlDir");

&loadconf::checkNeeds(
"maxGCLS",      "cleverness",
"ligLen",       "ligMinGc",         "ligMaxGc",     "ligMinTm",     "ligMaxTm",
"m13Len",       "m13MinGc",         "m13MaxGc",     "m13MinTm",     "m13MaxTm",
"primerFWD",    "primerREV");


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
my $exportSeq       = $pref{"exportSeq"};

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
		print "   $0 ACTUATOR /mnt/ssd/probes/dumps/Ashbya_gossypii_ATCC_10895_CHROMOSSOMES.fasta_3.xml\n\n";
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
				   $taxonID, $variant, $fastaFile, $sequenceType, $SQLinsertComplete1);

	if ($runned)
	{
		&printLog(1,	"FILE $fullFastaFile BY $inputFile ANALIZED");
		
		if ($actuatorDelete)
		{
			unlink($inputFile) or die "DIED: COULD NOT DELETE $inputFile: $!";
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
		"  $0 /var/rolf/input Ashbya_gossypii_ATCC_10895_CHROMOSSOMES.fasta 33169 0 2",
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
	
	my $outName = "$dumpDir/$fastaFile\_$MKFID.xml";
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

	&printInsert("organism", undef, $MKFID, $orgId,     $fastaFile,   $taxonID, $variant, $sequenceType);

	if ($verbose) { &printLogAC(2, "INSERTING ORGANISM:, ". $fastaFile. " > ". $orgId . "\n") };

	&printInsert("chromossome", undef, $MKFID, $orgId,    ($MKFID+1),         $chromShort,          $chromLong);

	if ($verbose) { &printLogAC(2, "INSERTING CHROMOSSOME: ". $fastaFile. " > ". ($MKFID+1) . " " . $chromLong . "\n") };

	my $MKFsequenceLength = length($sequence);

	   $countValAll        = 0;
	my $beforeGeneral      = time;
	my $beforeProbeGeneral = 0;
	my $p                  = 0;


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
			my $maxLigLen;
			
			my $mlpa = mlpaOO->new(\%pref, $revC);
			($ite, $lCountValAll, $centimo, $maxLigLen) = $mlpa->act(\@probe, $MKFsequence);
			$countValAll += $lCountValAll;
			
			#######################
			#### ACTUAL QUERIES
			#######################
			my $probeSize      = @probe;
			
			print "PROBE SIZE = $probeSize\n";

			if ($probeSize)
			{
				my $probeSizeBytes = size(\@probe);
				my $middle  = (int(($maxLigLen / 2)+.5)); # average size of probe size
				my $before  = time;
				my $lastLig = -300;
				my $nextDev = -300;

				my @values;
				my $valuesP = 0;
				for (my $pp = 0; $pp < $probeSize; $pp++)
				{
					$p++;
					my $localProbe = $probe[$pp];
					my $derivated  = 0;
					my $ligStat    = ${$localProbe}[0];
					my $strand     = ${$localProbe}[3];
				    #push (@probe,
					#[
					#[00]$ligStartF,
					#[01]$m13StartF,
					#[02]$m13EndF,
					#[03]$strand,
					#[04]&dnaCode::dna2digit($MKFligSeq),
					#[05]$ligGC,
					#[06]$ligTm,
					#[07]&dnaCode::dna2digit($MKFm13Seq),
					#[08]$m13GC,
					#[09]$m13Tm,
					#[10]&dnaCode::dna2digit("$MKFligSeq$MKFm13Seq"),
					#[11]$allGC,
					#[12]$allTm,
					#[13]&dnaCode::dna2digit(substr($MKFligSeq, -10) . substr($MKFm13Seq, 0, 10))
					#]
					#);
					if ($strand eq "R")
					{
						if ($lastLig == -300) { $lastLig = $ligStat - ($middle * -1) -1; };
						if ($nextDev == -300) { $nextDev = $ligStat - $middle; };
						if ((($lastLig-$middle) <= $ligStat) && ($lastLig >= $nextDev))
						{
							$derivated = 1;
						}
						else
						{
							$nextDev   = $ligStat-$middle;
						}
					} # end if reverse
					else
					{
						if ($lastLig == -300) { $lastLig = $ligStat + ($middle * -1) -1; };
						if ($nextDev == -300) { $nextDev = $ligStat + $middle; };
						if ((($lastLig+$middle) >= $ligStat) && ($lastLig <= $nextDev))
						{
							$derivated = 1;
						}
						else
						{
							$nextDev   = $ligStat+$middle;
						}
					} # end if forward

					$lastLig = $ligStat;

					if ($exportSQL)
					{
						if (defined $values[$valuesP][0]) { $values[$valuesP][0] .= ", "; };
						$values[$valuesP][0] .= "(\'" . $orgId . "\',\'" . ${$localProbe}[0] . "\',\'" . ${$localProbe}[1] . "\',\'" . ${$localProbe}[2] . "\',\'" . ${$localProbe}[3] . "\',\'" .  ($MKFID+1) . "\',\'" . $derivated . "\',\'" . ${$localProbe}[4] . "\',\'" . ${$localProbe}[5] . "\',\'" . ${$localProbe}[6] . "\',\'" . ${$localProbe}[7] . "\',\'" . ${$localProbe}[8] . "\',\'" . ${$localProbe}[9] . "\',\'" . ${$localProbe}[10] . "\',\'" .      ${$localProbe}[11] . "\',\'" . ${$localProbe}[12] . "\',\'" . ${$localProbe}[13] . "\')";
		#				                                                $ligStartF,                   $m13StartF,                   $m13EndF,                     $strand,                                                                     &dna2digit($MKFligSeq),       $ligGC,                       $ligTm,                       &dna2digit($MKFm13Seq),       $m13GC,                       $m13Tm,                       &dna2digit("$MKFligSeq$MKFm13Seq"), $allGC,                        $allTm,                        &dna2digit(substr($MKFligSeq, -10) . substr($MKFligSeq, 0, 10))]);
		#                                            idOrganism,        startLig,                     startM13,                     endM13,                       strand,                       chromossome,            derivated,             sequenceLig,                  sequenceLigGc,                sequenceLigTm,                sequenceM13,                  sequenceM13Gc,                sequenceM13Tm,                sequence,                           sequenceGc,                    sequenceTm,                    ligant";

					#[00]$ligStartF,
					#[01]$m13StartF,
					#[02]$m13EndF,
					#[03]$strand,
					#[04]&dnaCode::dna2digit($MKFligSeq),
					#[05]$ligGC,
					#[06]$ligTm,
					#[07]&dnaCode::dna2digit($MKFm13Seq),
					#[08]$m13GC,
					#[09]$m13Tm,
					#[10]&dnaCode::dna2digit("$MKFligSeq$MKFm13Seq"),
					#[11]$allGC,
					#[12]$allTm,
					#[13]&dnaCode::dna2digit(substr($MKFligSeq, -10) . substr($MKFm13Seq, 0, 10))

						if (size(\$values[$valuesP][0]) >= $max_packet_size * 0.98) { $valuesP++; };
					}
					if ($exportTAB)
					{


						$values[$valuesP][1] .= $orgId         . "\t" . ${$localProbe}[0]  . "\t" . ${$localProbe}[1]  . "\t" . 
											${$localProbe}[2]  . "\t" . ${$localProbe}[3]  . "\t" . ($MKFID+1)         . "\t" . 
											$derivated         . "\t" . ${$localProbe}[4]  . "\t" . ${$localProbe}[5]  . "\t" . 
											${$localProbe}[6]  . "\t" . ${$localProbe}[7]  . "\t" . ${$localProbe}[8]  . "\t" . 
											${$localProbe}[9]  . "\t" . ${$localProbe}[10] . "\t" . ${$localProbe}[11] . "\t" . 
											${$localProbe}[12] . "\t" . ${$localProbe}[13] . "\n";
					}
					#[saulo@SRV-FUNGI input]$ time mysql -u root --password=cbscbs12 < allatonce.sql 
					#real	985m3.975s
					#16h25m975s
					#user	0m29.737s
					#sys	0m2.783s

					#[saulo@SRV-FUNGI input]$ time mysql -u root --password=cbscbs12 < allatonce.q
					#real	990m56.858s
					#19h30m56s
					#user	0m0.003s
					#sys	0m0.005s


				} #end foreach my probe

				@probe = ();

				my $countValues = 1;
				foreach my $value (@values)
				{
					my $SQLfile  = "$sqlDir/$MKFfile." . &zerofy($MKFID, 3) . "." . &zerofy($countValues, 3) . ".$strand.sql";
					my $TABfile  = "$sqlDir/$MKFfile." . &zerofy($MKFID, 3) . "." . &zerofy($countValues, 3) . ".$strand.tab";
					$countValues++;
					$| = 1;
					&printLogAC(0, "\t\tEXPORTING SQL FILE $SQLfile\n");

					if ($exportSQL)
					{
						open SQLFILE, ">$SQLfile" or die "DIED: COULD NOT OPEN SQLFILE $SQLfile";
						print SQLFILE $SQLinsertComplete1, $value->[0], ";", "\n";
		#				print SQLFILE $value;
						close SQLFILE;
					}

					if ($exportTAB)
					{
						open TABFILE, ">$TABfile" or die "DIED: COULD NOT OPEN SQLFILE $TABfile";
						print TABFILE $value->[1];
						close TABFILE;
					}

					$| = 0;
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
				}
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
			$file = ${$sqlCodes{$code}}[0] .  "."  .$data[0] . "." . &zerofy($ac_id,3) . ".sql";
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


sub zerofy
{
		my $number    = $_[0];
		my $zeroes    = $_[1];
		my $outnumber = sprintf("%0".$zeroes."d", $number);
		return $outnumber;
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
sub revComp($)
{
	my $sequence = uc($_[0]);
	my $rev = reverse($sequence);
	$rev =~ tr/ACTG/TGAC/;
	return $rev;
}


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
sub savedump
{
    my $ref     = $_[0]; #reference
    my $name    = $_[1]; #name of variable to save
	my $outFile = $_[2];
    my $d = Data::Dumper->new([$ref],["*$name"]);

    $d->Purity   (1);     # better eval
#   $d->Terse    (0);     # avoid name when possible
    $d->Indent   (3);     # identation
    $d->Useqq    (1);     # use quotes
    $d->Deepcopy (1);     # enable deep copy, no references
    $d->Quotekeys(1);     # clear code
    $d->Sortkeys (1);     # sort keys
    $d->Varname  ($name); # name of variable
#    open (DUMP, ">$outFile.dump") or die "Cant save $outFile.dump file: $!\n";
    print $d->Dump or die "COULD NOT EXPORT HASH DUMP FROM PROBE_EXTRACTOR TO PROBE_EXTRACTOR_ACTUATOR: $!";
#    close DUMP;
};


sub load
{
    my $ref  = $_[0];
	my $file = $_[1];
	#	my $name = $_[1];

	die "DIED: FILE $file NOT FOUND" if ( ! -f $file );

    if (ref($ref) eq "HASH")
    {
            %{$ref} = %{retrieve("$file")} or die "DIED: COULD NOT RETRIEVE FILE $file: $!";
    }
	elsif (ref($ref) eq "ARRAY")
    {
            @{$ref} = @{retrieve("$file")} or die "DIED: COULD NOT RETRIEVE FILE $file: $!";;
    };

	#	return $ref;
    #%database = %{retrieve($prefix."_".$name."_store.dump")};
};

sub save
{
    my $ref  = $_[0];
    my $file = $_[1];
    store $ref, "$file" or die "COULD NOT SAVE DUMP FILE $file: $!";
#	return $ref;
};


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


