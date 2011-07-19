#!/usr/bin/perl -w
use warnings;
use strict;
use Storable;
use Data::Dumper;
use Devel::Size qw(size total_size);
use lib "./filters";
use dnaCode;
use filters::loadconf;
my %pref = &loadconf::loadConf;
#$pref{""}

#############################################
######## SETUP
#############################################
&loadconf::checkNeeds("actuatorDelete","maxGCLS","log","maxThreads","resetAtStart", "napTime", "cleverness","verbose","insertSize","max_packet_size",'@ligLen',"ligMinGc","ligMaxGc","ligMinTm","ligMaxTm",'@m13Len',"m13MinGc","m13MaxGc","m13MinTm","m13MaxTm","primerFWD","primerREV","database");

my $actuatorDelete  = $pref{"actuatorDelete"};

my $maxGCLS         = $pref{"maxGCLS"}; #MAX NUMBER OF CG ALLOWED IN THE LIGANT SITE (included)
my $log             = $pref{"log"} + 1;		#HOW VERBOSY 
my $maxThreads      = $pref{"maxThreads"};	
my $resetAtStart    = $pref{"resetAtStart"};

my $napTime         = $pref{"napTime"};			# time between each attempt to start a new thread if the number of threads exceeed maxtreads
my $cleverness      = $pref{"cleverness"};		# whether to skip elongation of m13 and skip half of lig once found a probe
my $verbose         = $pref{"verbose"};
my $insertSize      = $pref{"insertSize"};		# number of registers to insert at coordinates at a time
my $max_packet_size = $pref{"max_packet_size"};	# max_insertion_size in mysql configuration (in bytes)

my $exportSQL       = $pref{"exportSQL"};
my $exportTAB       = $pref{"exportTAB"};


my @ligLen          = @{$pref{'@ligLen'}};
my $ligMinGc        = $pref{"ligMinGc"}; # in %
my $ligMaxGc        = $pref{"ligMaxGc"}; # in %
my $ligMinTm        = $pref{"ligMinTm"}; # in centigrades [69];
my $ligMaxTm        = $pref{"ligMaxTm"}; # in centigrades [76];

my @m13Len          = @{$pref{'@m13Len'}};
my $m13MinGc        = $pref{"m13MinGc"};
my $m13MaxGc        = $pref{"m13MaxGc"};
my $m13MinTm        = $pref{"m13MinTm"};# in centigrades [70];
my $m13MaxTm        = $pref{"m13MaxTm"};# in centigrades [100];

my $primerFWD       = $pref{"primerFWD"};
my $primerREV       = $pref{"primerREV"};

my $exportSeq       = 1;

#############################################
######## USAGE DECLARATIONS
#############################################
`sudo renice -10 $$`;
use List::Util qw[min max];
use threads;
use threads::shared;
use threads 'exit'=>'threads_only';



#############################################
######## CHECKINGS AND DECLARATIONS
#############################################
my %inputHash;
my $inputFile = $ARGV[0];

if ( ! ( $ARGV[0] ) )
{
	print "USAGE: $0 </full/path/to/dump/file>\n";
	print "</full/path/to/dump/file> Perl hash dump containing variables\n";
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

my %idKey     ;
my @idKeyRev  ;
my $totalSeq  ;
my $totalFrag ;
my @seqKeyRev ;

my $ligSize     = @ligLen;
my $m13Size     = @m13Len;
my $minLigLen   = min(@ligLen);
my $minM13Len   = min(@m13Len);
my $maxLigLen   = max(@ligLen);
my $maxM13Len   = max(@m13Len);

my $WCkeyS;
my $countDB     = 0;
my $countDBLig  = 0;
my $countDBM13  = 0;

my $statingTime = time;
my $lastTime    = $statingTime;
my $centimo     = 0;
my $lastVal     = 0;
my $countValAll = 0;
my $tElapsed    = 0;

my $primerFWDrc = reverse("$primerFWD");
my $primerREVrc = reverse("$primerREV");
   $primerFWDrc =~ tr/ACTG/TGAC/;
   $primerREVrc =~ tr/ACTG/TGAC/;

my $runned      = 0;

####################################################
####### SQL STATEMENTS
####################################################
#use DBI;
#use DBD::mysql;

#my $host      = 'localhost';
my $database  = $pref{"database"};
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
my $SQLinsertComplete1   = "INSERT INTO `$database`.`complete`      (idprobe, idOrganism, startLig, startM13, endM13, strand, chromossome, derivated) VALUES ";
my $SQLinsertLig         = "INSERT INTO `$database`.`uniq_Lig`      (idprobe, sequenceLig, sequenceLigGc, sequenceLigTm) VALUES ";
my $SQLinsertM13         = "INSERT INTO `$database`.`uniq_M13`      (idprobe, sequenceM13, sequenceM13Gc, sequenceM13Tm) VALUES ";
my $SQLinsertSequence    = "INSERT INTO `$database`.`uniq_Sequence` (idprobe, sequence,    sequenceGc,    sequenceTm)    VALUES ";
my $SQLinsertLigant      = "INSERT INTO `$database`.`uniq_Ligant`   (idprobe, ligant)      VALUES ";
my $SQLinsertCount       = "ON DUPLICATE KEY UPDATE idprobe=LAST_INSERT_ID(idprobe), count=count+1";


my %sqlCodes;
	$sqlCodes{"organism"}[0]    = "$sqlDir/organism.sql";
	$sqlCodes{"organism"}[1]    = "INSERT IGNORE INTO `$database`.`organism` (idorganism, nameOrganism, taxonId, variant, sequenceTypeId) VALUES";
	$sqlCodes{"organism"}[2]    = "ON DUPLICATE KEY UPDATE idorganism=LAST_INSERT_ID(idorganism), count=count+1";

	$sqlCodes{"chromossome"}[0] = "$sqlDir/chromossome.sql";
	$sqlCodes{"chromossome"}[1] = "INSERT IGNORE INTO `$database`.`chromossomes` (idOrganism, chromossomeNumber, chromossomeShortName, chromossomeLongName)        VALUES";
	$sqlCodes{"chromossome"}[2] = "ON DUPLICATE KEY UPDATE chromossomes.chromossomeNumber=chromossomes.chromossomeNumber";

#&cleanCodes();

#my $dbh;




#############################################
######## INITIATION
#############################################
	my $progStartTime = time;
	my $progTotalBp   = 0;

#	unlink("log.txt");

	&printLog(1, "RUNNING OVER FILE $fullFastaFile BY $inputFile\n");

	&printLog(1, "MAKING FRAGMENTS FOR $ac_file " . $ac_id_long . "[$ac_id] (" . length($ac_sequence) . "bp)\n");
	&mkFragments($ac_file, $ac_id, $ac_sequence, $ac_id_short, $ac_id_long);

	if ($runned)
	{
		&printLog(1,	"FILE $fullFastaFile BY $inputFile ANALIZED WITH:\n" .
			" LIG GC% ] $ligMinGc,$ligMaxGc [, M13 GC% ] $m13MinGc,$m13MaxGc [," .
			" LIG TM  ] $ligMinTm,$ligMaxTm [, M13 TM  ] $m13MinTm,$m13MaxTm [," .
			" LENGTH LIG ( " . $ligSize . " ), LENGTH M13 ( " . $m13Size . " )\ndone\n");
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



#############################################
######## FUNCTIONS
#############################################

sub mkFragments
{
	my $MKFfile    = $_[0];
	my $MKFID      = $_[1];
	my $sequence   = uc($_[2]);
	my $chromShort = $_[3];
	my $chromLong  = $_[4];
	my $revC       = 0;
	my $rev;

	$0 = "$0 :: $MKFfile : $MKFID";

	#$dbh = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>0, PrintError=>0, AutoCommit=>0}) or die "DIED: COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

	
	#my $insertOrganism    = $dbh->prepare_cached($SQLinsertOrganism )    or die "DIED: COULD NOT PREPARE ORGANISM    QUERY: " . $DBI::errstr; #(INSERT IGNORE)
	#my $insertChromossome = $dbh->prepare_cached($SQLinsertChromossome ) or die "DIED: COULD NOT PREPARE CHROMOSSOME QUERY: " . $DBI::errstr; #(INSERT IGNORE)
	#my $insertProbe       = $dbh->prepare_cached($SQLinsertProbe  )      or die "DIED: COULD NOT PREPARE PROBE       QUERY: " . $DBI::errstr;

	#						FILE	TaxonomyID variant  SequenceType

	my $orgId    = "$taxonID.$variant";

	#                              ( idorganism, nameOrganism, taxonId,  variant,  sequenceTypeId)
	&printInsert("organism", undef, $orgId,     $fastaFile,   $taxonID, $variant, $sequenceType);
	#$insertOrganism->execute($fastaFile, $taxonID, $variant, $sequenceType) or die "DIED: COULD NOT EXECUTE ORGANISM QUERY: " . $DBI::errstr;
	#my $orgId   = $insertOrganism->{'mysql_insertid'};

	#my $orgRows = $insertOrganism->rows;
	#if ( ! ($orgRows) ) {die "DIED: NO ROWS AFFECT BY ORGANISM INSERTION"};
	#$insertOrganism->finish();
	if ($verbose) { &printLog(2, "INSERTING ORGANISM:, ". $fastaFile. " > ". $orgId . "\n") };

	#							        orgID       chromID	           chromNameShort		 chromNameLong
    #                                  (idOrganism, chromossomeNumber, chromossomeShortName, chromossomeLongName)
	&printInsert("chromossome", undef, $orgId,    ($MKFID+1),         $chromShort,          $chromLong);

	#$insertChromossome->execute($orgId, ($MKFID+1), $MKFID, $chromLong) or die "DIED: COULD NOT EXECUTE CHROMOSSOME QUERY: " . $DBI::errstr;
	#my $chromId   = $insertChromossome->{'mysql_insertid'};
	#my $chromRows = $insertChromossome->rows;
	#if ( ! ($chromRows) ) {die "DIED: NO ROWS AFFECT BY CHROMOSSOME INSERTION"};
	#$insertChromossome->finish();
	if ($verbose) { &printLog(2, "INSERTING CHROMOSSOME: ". $fastaFile. " > ". ($MKFID+1) . " " . $chromLong . "\n") };


	#$dbh->commit();

	my $MKFsequenceLength = length($sequence);
	my $lastLigStart      = $MKFsequenceLength - ($minLigLen + $minM13Len);

	my $ligEnd;
	my $m13Start;
	my $m13End;
	my $MKFligSeq;
	my $MKFm13Seq;
	my $ligThree;
	my $m13Three;
	   $countValAll        = 0;
	my $beforeGeneral      = time;
	my $beforeProbeGeneral = 0;
	my $p                  = 0;

	if ($exportSeq)
	{
		for my $MKFsequence ($sequence, $sequence)
		{
			my @probe;
			my $strand = "F";
			if ( $revC ) 
			{
				$strand = "R";
				$rev    = " REV"; 
				$MKFsequence = reverse($MKFsequence);  
				$MKFsequence =~ tr/ACTG/TGAC/; 
			}
			else 
			{ 
				$strand = "F";
				$rev    = " FWD"; 
			};

			my $ligStart = 1;
			my $count    = 1;
			my $total    = $lastLigStart;
			   $centimo  = int(($total / 10) + 0.5);

			undef $ligEnd;
			undef $m13Start;
			undef $m13End;
			undef $MKFligSeq;
			undef $MKFm13Seq;
			undef $ligThree;
			undef $m13Three;

			my $ite = 0;
			while ($ligStart < $lastLigStart)
			{
				my $found = 0;
				my $ligLen;

				for $ligLen (@ligLen)
				{
					if ($found) { last; };
					$ligEnd    = $ligStart + $ligLen - 1;
					$MKFligSeq = substr($MKFsequence, $ligStart-1, $ligLen);

					############# LIG CONSTRAINS ##################
					my $start = 0;
					$ite++;
					while ((substr($MKFligSeq, $start, 1) =~ /[A|T]/) && ($start < $ligLen)) { $ligStart++; $start++; };

					if ( $MKFligSeq =~ /^[A|T]/) { $ligStart--; last; }; # &printLog(0, "LIG STARTS WITH A|T @ $ligStart \t$MKFligSeq\n"); 
					# THE LIGSTART-- IS DUE TO THE WHILE LOOP

					if ( $MKFligSeq =~ /[G|T]$/) { next; }; # &printLog(2, "LIG STARTS WITH A|T OR ENDS WITH G|T\t$MKFligSeq\n"); 
					if ( $MKFligSeq =~ /N/)      { last; };

					if (($MKFligSeq =~ /$primerFWD/)   || ($MKFligSeq =~ /$primerREV/)   ||	#PRIMERS 
						($MKFligSeq =~ /$primerFWDrc/) || ($MKFligSeq =~ /$primerREVrc/))	#PRIMERS REVERSE COMPLEMENTAR
					{ last; }; 

					my $ligGC   = &countGC($MKFligSeq);
					if ( ! (($ligGC >=       $ligMinGc)  && ($ligGC <=      $ligMaxGc))  ) { next; }; # &printLog(2, "LIG WRONG GC% $ligMinGc < $ligGC < $ligMaxGc\t$MKFligSeq\n");

					my $ligTm   = &tm($MKFligSeq, $ligGC);
					if      ($ligTm > $ligMaxTm)                                           { last; }; # &printLog(2, "LIG WRONG TM $ligMinTm < $ligTm < $ligMaxTm\t$MKFligSeq\n"); 
					if ( ! (($ligTm >=       $ligMinTm)  && ($ligTm <=      $ligMaxTm))  ) { next; }; # &printLog(2, "LIG WRONG TM $ligMinTm < $ligTm < $ligMaxTm\t$MKFligSeq\n"); 

					$ligThree = substr($MKFligSeq, -3);
					if (($ligThree =~ s/[G|C]//g) > $maxGCLS) { next; }; # &printLog(2, "LIG ENDS WITH TOO MUCH GC\t$MKFligSeq\n"); 

					my $m13Len;
					for $m13Len (@m13Len)
					{
						if ($found && $cleverness) { last; };
						$ite++;
						if ( ! ($m13Len % 3) ) { next; };

						$m13Start = $ligEnd   + 1;
						$m13End   = $m13Start + $m13Len - 1;
						if ( $m13End > $MKFsequenceLength ) { last; };

						############# M13 CONSTRAINS ##################
						$MKFm13Seq   = substr($MKFsequence, $m13Start-1, $m13Len);

						if ( $MKFm13Seq =~ /N/)      { last; };

						if (($MKFm13Seq =~ /$primerFWD/)   || ($MKFm13Seq =~ /$primerREV/)   ||	#PRIMERS 
							($MKFm13Seq =~ /$primerFWDrc/) || ($MKFm13Seq =~ /$primerREVrc/))	#PRIMERS REVERSE COMPLEMENTAR
						{ last; }; 

						if (($MKFm13Seq =~ /GAATGC/) || ($MKFm13Seq =~ /CTTACG/) ||	#BSM1
							($MKFm13Seq =~ /GATATC/) || ($MKFm13Seq =~ /CTATAG/) ||	#ECORV
							($MKFm13Seq =~ /GAGCTC/) || ($MKFm13Seq =~ /CTCGAG/))	#SCAI
						{ last; }; 

						my $m13GC   = &countGC($MKFm13Seq);
						if ( ! (($m13GC >= $m13MinGc)        && ($m13GC <=      $m13MaxGc))  ) { next; }; # &printLog(2, "M13 WRONG GC% $m13MinGc < $m13GC < $m13MaxGc\t$MKFm13Seq\n"); 

						my $m13Tm = &tm($MKFm13Seq, $m13GC);
						if ( $m13Tm > $m13MaxTm)                                               { last; }; #&printLog(2, "M13 WRONG TM $m13MinTm < $m13Tm < $m13MaxTm\t$MKFm13Seq\n"); 
						if ( ! (($m13Tm >=       $m13MinTm)  && ($m13Tm <=      $m13MaxTm))  ) { next; }; #&printLog(2, "M13 WRONG TM $m13MinTm < $m13Tm < $m13MaxTm\t$MKFm13Seq\n"); 

						$m13Three = substr($MKFm13Seq, 0, 3);
						if (($m13Three =~ s/[G|C]//g) > $maxGCLS) { next; }; #&printLog(2, "M13 STARTS WITH TOO MUCH GC\t$MKFm13Seq\n"); 


						my $MKFallSeq = "$MKFligSeq$MKFm13Seq";
						my $allGC     = &countGC($MKFallSeq); # todo, delete to be faster
						my $allTm     = &tm($MKFallSeq, $allGC);

						my $ligStartF = $ligStart;
						my $m13StartF = $m13Start;
						my $m13EndF   = $m13End;

						if ($rev eq " REV")
						{
							$ligStartF = $MKFsequenceLength - $ligStart+1;
							$m13StartF = $MKFsequenceLength - $m13Start+1;
							$m13EndF   = $MKFsequenceLength - $m13End+1;
						} #end if rev

						push (@probe, [$ligStartF, $m13StartF, $m13EndF, $strand, &dnaCode::dna2digit($MKFligSeq), $ligGC, $ligTm, &dnaCode::dna2digit($MKFm13Seq), $m13GC, $m13Tm, &dnaCode::dna2digit("$MKFligSeq$MKFm13Seq"), $allGC, $allTm, &dnaCode::dna2digit(substr($MKFligSeq, -10) . substr($MKFm13Seq, 0, 10))]);

						$countValAll++;
						$found = 1;
					}; # END FOR MY M13LEN
				}; # END FOR MY LIGLEN
				$ligStart++;
			} # END FOR MY $LIGSTART

	
			#######################
			#### ACTUAL QUERIES
			#######################
			my $probeSize      = @probe;

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
						if (defined $values[$valuesP][1]) { $values[$valuesP][1] .= ", "; };
						if (defined $values[$valuesP][2]) { $values[$valuesP][2] .= ", "; };
						if (defined $values[$valuesP][3]) { $values[$valuesP][3] .= ", "; };
						if (defined $values[$valuesP][4]) { $values[$valuesP][4] .= ", "; };



						my $probeId = "$orgId." . ($MKFID+1) . ".$pp." . ${$localProbe}[3];
						$values[$valuesP][0] .= "(\'" . $probeId . "\',\'" . $orgId . "\',\'" . ${$localProbe}[0] . "\',\'" . ${$localProbe}[1] . "\',\'" . ${$localProbe}[2] . "\',\'" . ${$localProbe}[3] . "\',\'" .  ($MKFID+1) . "\',\'" . $derivated . "\')";
		#"INSERT INTO `$database`.`complete`     (idprobe,                  idOrganism,         startLig,                     startM13,                     endM13,                       strand,                        chromossome,           derivated)  VALUES ";
		#				                                                                        $ligStartF,                   $m13StartF,                   $m13EndF,                     $strand,                                                                     &dna2digit($MKFligSeq),       $ligGC,                       $ligTm,                       &dna2digit($MKFm13Seq),       $m13GC,                       $m13Tm,                       &dna2digit("$MKFligSeq$MKFm13Seq"), $allGC,                        $allTm,                        &dna2digit(substr($MKFligSeq, -10) . substr($MKFligSeq, 0, 10))]);
		#                                            idOrganism,        startLig,                     startM13,                     endM13,                       strand,                       chromossome,            derivated,             sequenceLig,                  sequenceLigGc,                sequenceLigTm,                sequenceM13,                  sequenceM13Gc,                sequenceM13Tm,                sequence,                           sequenceGc,                    sequenceTm,                    ligant";

						my $sequenceLig = ${$localProbe}[4];
						my $sequenceM13 = ${$localProbe}[7];
						my $sequence    = ${$localProbe}[10];
						my $ligant      = ${$localProbe}[13];

						$values[$valuesP][1] .= "(\'" . $probeId . "\',\'" . $sequenceLig . "\',\'" . ${$localProbe}[5]  . "\',\'" . ${$localProbe}[6]  . "\')";
						$values[$valuesP][2] .= "(\'" . $probeId . "\',\'" . $sequenceM13 . "\',\'" . ${$localProbe}[8]  . "\',\'" . ${$localProbe}[9]  . "\')";
						$values[$valuesP][3] .= "(\'" . $probeId . "\',\'" . $sequence    . "\',\'" . ${$localProbe}[11] . "\',\'" . ${$localProbe}[12] . "\')";
						$values[$valuesP][4] .= "(\'" . $probeId . "\',\'" . $ligant      . "\')";

						if (size(\$values[$valuesP][0]) >= $max_packet_size * 0.98)
						{
							#$values[$valuesP][1] .= " $SQLinsertCount";
							#$values[$valuesP][2] .= " $SQLinsertCount";
							#$values[$valuesP][3] .= " $SQLinsertCount";
							#$values[$valuesP][4] .= " $SQLinsertCount";
							$valuesP++;
						};
					}
					if ($exportTAB)
					{


						$values[$valuesP][5] .= $orgId         . "\t" . ${$localProbe}[0]  . "\t" . ${$localProbe}[1]  . "\t" . 
											${$localProbe}[2]  . "\t" . ${$localProbe}[3]  . "\t" . ($MKFID+1)         . "\t" . 
											$derivated         . "\t" . ${$localProbe}[4]  . "\t" . ${$localProbe}[5]  . "\t" . 
											${$localProbe}[6]  . "\t" . ${$localProbe}[7]  . "\t" . ${$localProbe}[8]  . "\t" . 
											${$localProbe}[9]  . "\t" . ${$localProbe}[10] . "\t" . ${$localProbe}[11] . "\t" . 
											${$localProbe}[12] . "\t" . ${$localProbe}[13] . "\n";
					}
				} #end foreach my probe

				@probe = ();

				my $countValues = 1;
				foreach my $value (@values)
				{
					my $SQLfile  = "$sqlDir/$MKFfile.$MKFID.$countValues.$strand.sql";
					my $TABfile  = "$sqlDir/$MKFfile.$MKFID.$countValues.$strand.tab";
					$countValues++;
					$| = 1;
					&printLog(0, "\t\tEXPORTING SQL FILE $SQLfile\n");

					if ($exportSQL)
					{
						open  SQLFILE, ">$SQLfile" or die "DIED: COULD NOT OPEN SQLFILE $SQLfile";
						print SQLFILE $SQLinsertComplete1, $value->[0], ";\n\n";
						print SQLFILE $SQLinsertLig,       $value->[1], ";\n\n";
						print SQLFILE $SQLinsertM13,       $value->[2], ";\n\n";
						print SQLFILE $SQLinsertSequence,  $value->[3], ";\n\n";
						print SQLFILE $SQLinsertLigant,    $value->[4], ";\n\n";
		#				print SQLFILE $value;
						close SQLFILE;
					}

					if ($exportTAB)
					{
						open TABFILE, ">$TABfile" or die "DIED: COULD NOT OPEN SQLFILE $TABfile";
						print TABFILE $value->[5];
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
				&printLog(1,  "\t\t". $probeSize. " PROBES INSERTED IN ". $probeElapsed. " s (". $pbs. " probes/s) FOR " . $ac_id_long . $rev. "\n");
			} #end if probe
			else
			{
				&printLog(1, "NO PROBES FOUND AFTER $ite ITERATIONS\n");
			}
			$revC++;
		} # end foreach my $sequence revComp(sequence)
	}

	my $elapsed      = time-$beforeGeneral;
	my $elapsedProbe = $beforeProbeGeneral;
	my $pbs  = $elapsed      ? int($countValAll       / $elapsed)      : $countValAll;
	my $mbs  = $elapsed      ? int($MKFsequenceLength / $elapsed)      : $MKFsequenceLength;
	my $pIbs = $elapsedProbe ? int($countValAll       / $elapsedProbe) : $countValAll;	
	&printLog(1, "\tSEQUENCE ". $MKFfile. " "  . $ac_id_long . " ANALIZED IN ". $elapsed. " s\n" . 
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
	my $code = $_[0];
	my $file = $_[1];
	my @data = @_[2 .. (@_-1)];

	if (exists $sqlCodes{$code})
	{
		if (defined ${$sqlCodes{$code}}[0])
		{
			$file = ${$sqlCodes{$code}}[0];
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
sub revComp($)
{
	my $sequence = uc($_[0]);
	my $rev = reverse($sequence);
	$rev =~ tr/ACTG/TGAC/;
	return $rev;
}


sub printLog
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


sub tm
{
	my $seq       = $_[0];
	my $gc        = $_[1];
	my $NaK       = 0.05; # 35mM 0.035M
# 	my $cgCount   = $seq;
# 	   $cgCount   = ($cgCount =~ s/[C|G]//gi);;

	my $tm   = 81.5    + (16.6    *  (&log10($NaK)))       + (0.41   *   $gc)   - (675/length($seq));
#       Tm   = 81.5°C  +  16.6°C  x  (log10[Na+] + [K+])  +  0.41°C  x  (%GC)  –  675/N

	$tm = (1.0701*$tm) + 14.646; # regression from 4 points to raw-probe
	
	return int($tm + .5);


#http://www.promega.com/biomath/calc11.htm#melt_results
#Where N is the length of the primer.

}



sub log10 {
	my $n = shift;
	return log($n)/log(10);
}


sub countGC
{
	my $seqGC    = $_[0];
	my $lengthGC = length($seqGC);
# 	print "$seq (" . length($seq) . ")\t";
	my $count    = ($seqGC =~ s/[C|G]//gi);
# 	print "$seq (" . length($seq) . ")\t$count\t";
	my $gc       = ($count / $lengthGC) * 100;
# 	print "gc $gc\n";
	return int($gc + .5);
}















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
    print $d->Dump;
#    close DUMP;
};


sub save
{
        my $ref  = $_[0];
        my $file = $_[1];
        store $ref, "$file";
#	return $ref;
};

sub load
{
    my $ref  = $_[0];
	my $file = $_[1];
	#	my $name = $_[1];
    &printLog(0, "LOADING DATABASE....");

	die "DIED: FILE $file NOT FOUND" if ( ! -f $file );

    if (ref($ref) eq "HASH")
    {
            %{$ref} = %{retrieve("$file")} or die "DIED: COULD NOT RETRIEVE FILE $file: $!";
    }
	elsif (ref($ref) eq "ARRAY")
    {
            @{$ref} = @{retrieve("$file")} or die "DIED: COULD NOT RETRIEVE FILE $file: $!";;
    };
	&printLog(0, "done\n");
	#	return $ref;
    #%database = %{retrieve($prefix."_".$name."_store.dump")};
};



sub saveXML
{
    my $ref  = $_[0];
    my $file = $_[1];

    if (ref($ref) eq "HASH")
    {
		open DUMPXML, ">$file" or die "COULD NOT SAVE DUMPXML $file: $!";

		#print DUMPXML "<xml>\n";
		foreach my $key (sort keys %{$ref})
		{
			my $value = \$ref->{$key};
			$value =~ tr/\n//;
			$value =~ tr/\r//;
			print DUMPXML "\t<", $key, ">",$$value,"</", $key, ">\n";
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

