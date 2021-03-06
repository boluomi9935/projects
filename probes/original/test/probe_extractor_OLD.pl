#!/usr/bin/perl -w
use warnings;
use strict;

#compacting
#real	1m25.516s
#user	0m40.605s
#sys	0m2.824s
# 5.52mb 5.52

#compacting + small size
#real	1m22.113s
#user	0m40.338s
#sys	0m2.684s
# 5.52mb 5.52

#compacting + small size + pack all
#real	1m19.349s
#user	0m40.116s
#sys	0m2.752s
# 5.52mb 5.52

#compacting + small size + pack all + compressed row
#real	1m17.862s
#user	0m39.938s
#sys	0m2.740s


#not compacting
#real	1m37.807s
#user	0m39.308s
#sys	0m2.824s
#9.52 11.58


#############################################
######## SETUP
#############################################
my $maxGCLS      = 2; #MAX NUMBER OF CG ALLOWED IN THE LIGANT SITE (included)
my $log          = 0; #HOW VERBOSY 
my $maxThreads   = 3;	
my $resetAtStart = 0;

my $napTime      = 1; # time between each attempt to start a new thread if the number of threads exceeed maxtreads
my $cleverness   = 1; #whether to skip elongation of m13 and skip half of lig once found a probe
my $verbose      = 0;
my $insertSize   = 5000; #number of registers to insert at coordinates at a time

my @ligLen       = qw( 21 23 24 26 27 29 30 32 33 35 36 38 39 );
my $ligMinGc     = 45; # in %
my $ligMaxGc     = 60; # in %
my $ligMinTm     = 75; # in centigrades [69];
my $ligMaxTm     = 82; # in centigrades [76];

my @m13Len       = qw( 37 38 40 41 43 44 46 47 49 50 );
my $m13MinGc     = 35;
my $m13MaxGc     = 60;
my $m13MinTm     = 75;# in centigrades [70];
my $m13MaxTm     = 90;# in centigrades [100];

my $primerFWD    = "GTGGCAGGGCGCTACGAACAA";
my $primerREV    = "GGACGCGCCAGCAAGATCCAATCTAGA";



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
my $indir        = $ARGV[0];
my $file         = $ARGV[1];
my $taxonID      = $ARGV[2];
my $variant		 = $ARGV[3];
my $sequenceType = $ARGV[4];


if ( ! (@ARGV[0 .. 4]))
{
print "USAGE: $0 indir file NCBI_taxon_id variant sequence_type\n";
print "       variant: if a strain or subspecie is not present in ncbi, use the root ncbi id and increment the variant count\n";
print 
"       sequence type: CDS          1
                       CHROMOSSOMES 2
                       CIRCULAR     3
                       CONTIGS      4
                       COMPLETE     5
                       GENES        6
                       ORF          7
                       PARTIAL      8
                       WGS SCAFFOLD 9
";
exit(1); 
};

if ( ! ( -d $indir         ) ) { die "INPUT  DIR $indir  DOESNT EXISTS: $!"};
if ( ! ( -f "$indir/$file" ) ) { die "INPUT FILE $file   DOESNT EXISTS: $!"};


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

my @dnaKey;
my %keyDna;
my @DIGIT_TO_CODE;
my %CODE_TO_DIGIT;
&loadVariables();

####################################################
####### SQL STATEMENTS
####################################################
if ($resetAtStart)
{
	`/home/saulo/Desktop/rolf/sql/startSql.sh`;
}
use DBI;
use DBD::mysql;

my $host      = 'localhost';
my $database  = 'probe';
my $user      = 'probe';
my $pw        = '';
# probe  1.22
# probe2 1.19
my $SQLinsertOrganism    = "INSERT IGNORE INTO organism     (nameOrganism, taxonId, variant, sequenceTypeId)                                  VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE idorganism=LAST_INSERT_ID(idorganism), count=count+1";
my $SQLinsertChromossome = "INSERT IGNORE INTO chromossomes (idOrganism, chromossomeNumber, chromossomeShortName, chromossomeLongName)        VALUES (?, ?, ?,?)  ON DUPLICATE KEY UPDATE chromossomes.chromossomeNumber=chromossomes.chromossomeNumber";
my $SQLinsertProbe       = "INSERT IGNORE INTO probe        (sequenceLig, sequenceM13, probeGc, probeTm)                                      VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE idprobe=LAST_INSERT_ID(idprobe)      , count=count+1";
my $SQLinsertCoord1      = "INSERT IGNORE INTO coordinates  (idOrganism, idProbe, startLig, startM13, endM13, strand, chromossome, derivated) VALUES ";
my $SQLinsertCoord2      = " ON DUPLICATE KEY UPDATE idcoordinates=LAST_INSERT_ID(idCoordinates), count=count+1";

my $dbh;



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

	&printLog(0, "RUNNING OVER FILE $indir/$file\n");

	&getFasta("$indir/$file");

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
		&printLog(0,	"$totalSeq SEQUENCES ON FILE $indir/$file" .
			" LIG GC% ] $ligMinGc,$ligMaxGc [, M13 GC% ] $m13MinGc,$m13MaxGc [," .
			" LIG TM  ] $ligMinTm,$ligMaxTm [, M13 TM  ] $m13MinTm,$m13MaxTm [," .
			" LENGTH LIG ( " . $ligSize . " ), LENGTH M13 ( " . $m13Size . " )\ndone\n");
		&printLog(0,	"$progTotalBp bp on " . (time - $progStartTime) . " s [ " . (int(($progTotalBp/(time - $progStartTime))+.5)) . " bp/s ]\n");
	}
	else
	{
		die "A PROBLEM WAS FOUND WHILE RUNNING. PLEASE CHECK YOUR FASTA FILE";
	}
	undef @seqKeyRev;
	undef %idKey;
	undef @idKeyRev;
	undef $totalSeq;
	undef $totalFrag;

close LOG;



#############################################
######## FUNCTIONS
#############################################

sub mkFragments
{
	my $MKFfile  = $_[0];
	my $MKFID    = $_[1];
	my $sequence = uc($_[2]);
	my $revC     = 0;
	my $rev;

	$0 = "$0 :: $MKFfile : $MKFID";

	$dbh = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>0, PrintError=>0, AutoCommit=>0})
		 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

	
	my $insertOrganism    = $dbh->prepare_cached($SQLinsertOrganism )    or die "COULD NOT PREPARE ORGANISM    QUERY: " . $DBI::errstr; #(INSERT IGNORE)
	my $insertChromossome = $dbh->prepare_cached($SQLinsertChromossome ) or die "COULD NOT PREPARE CHROMOSSOME QUERY: " . $DBI::errstr; #(INSERT IGNORE)
	my $insertProbe       = $dbh->prepare_cached($SQLinsertProbe  )      or die "COULD NOT PREPARE PROBE       QUERY: " . $DBI::errstr;

	#						FILE	TaxonomyID variant  SequenceType
	$insertOrganism->execute($file, $taxonID, $variant, $sequenceType) or die "COULD NOT EXECUTE ORGANISM QUERY: " . $DBI::errstr;
	my $orgId   = $insertOrganism->{'mysql_insertid'};
	my $orgRows = $insertOrganism->rows;
	if ( ! ($orgRows) ) {die "NO ROWS AFFECT BY ORGANISM INSERTION"};
	$insertOrganism->finish();
	if ($verbose) { print "INSERTING ORGANISM: $file > $orgId >> $orgRows\n"; };

	#							orgID	chromID		chromNameShort			chromNameLong
	$insertChromossome->execute($orgId, ($MKFID+1), $idKeyRev[$MKFID][0], $idKeyRev[$MKFID][1]) or die "COULD NOT EXECUTE CHROMOSSOME QUERY: " . $DBI::errstr;
	my $chromId   = $insertChromossome->{'mysql_insertid'};
	my $chromRows = $insertChromossome->rows;
	if ( ! ($chromRows) ) {die "NO ROWS AFFECT BY CHROMOSSOME INSERTION"};
	$insertChromossome->finish();
	if ($verbose) { print "INSERTING CHROMOSSOME: $file > $chromId >> $chromRows\n"; };


	$dbh->commit();

	my $MKFsequenceLength = length($sequence);
	my $lastLigStart      = $MKFsequenceLength - ($minLigLen + $minM13Len);

	my $ligEnd;
	my $m13Start;
	my $m13End;
	my $MKFligSeq;
	my $MKFm13Seq;
	my $ligThree;
	my $m13Three;
	   $countValAll   = 0;
	my $beforeGeneral = time;

	for my $MKFsequence ($sequence, $sequence)
	{
		my @probe;
		my $p = 0;
		my $strand = "F";
		if ( $revC ) 
		{
			$strand = "R";
			$rev = " REV"; 
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

		my $probeElapsed  = 0;
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

					push (@probe, [&dna2digit($MKFligSeq), &dna2digit($MKFm13Seq), $allGC, $allTm, $ligStartF, $m13StartF, $m13EndF, $strand]);
					$countValAll++;
					$found = 1;
				}; # END FOR MY M13LEN
			}; # END FOR MY LIGLEN

			#######################
			#### ACTUAL QUERIES
			#######################
			my $probeSize = @probe;
			if (($probeSize > $p) || ($ligStart == ($lastLigStart-1)))
			{
				my $before = time;
				for ($p = $p; $p < $probeSize; $p++)
				{
					my $working    = 1;
					my $crashed    = 0;
					my $startCrash = 0;
					my $localProbe = $probe[$p];
					while ($working)
					{
						$insertProbe->execute(${$localProbe}[0], ${$localProbe}[1], ${$localProbe}[2], ${$localProbe}[3]);
#					          push (@probe, [&dna2digit($MKFligSeq), &dna2digit($MKFm13Seq), $allGC, $allTm, $ligStartF, $m13StartF, $m13EndF, $strand]);
						# or print "COULD NOT EXECUTE PROBE QUERY: " . ${$probe[$p]}[0] . " " . ${$probe[$p]}[1] . " " . ${$probe[$p]}[2] . " : " . $idKeyRev[$MKFID][1] . " " . $DBI::errstr . "\n";
						if ( ! (defined $DBI::errstr) )
						{
							$insertProbe->finish();
							$working = 0;
						}
						elsif ((defined $DBI::err) && ($DBI::err == 1213))
						{
							$crashed = 1;
						}
						else
						{
							die "COULD NOT EXECUTE PROBE QUERY: " . ${$localProbe}[0] . " " . ${$localProbe}[1] . " " . ${$localProbe}[2] . " : " . $idKeyRev[$MKFID][1] . " " . $DBI::errstr . "\n";
						}
					}	
					my $proId   = $insertProbe->{'mysql_insertid'};
					my $proRows = $insertProbe->rows;
			
					if (( ! ($proRows || $proId) ) || ( ($proRows  == 0) || ( ! (defined $proRows))) || ( $proId  == -1 ))
					{
						print "@"x30 . "\n";
						print "@ ORG: $file ($orgId)\n";
						print "@ \t" . join("\t", @{$localProbe}) . " " . ($MKFID+1) . "\n\n";
						print "@"x30 . "\n";
						if ( ! ($proRows || $proId) )                     { die "NO ROWS AFFECT BY PROBE INSERTION: BOTH INVALID"; };
						if ( ($proRows  == 0) || ( ! (defined $proRows))) { die "NO ROWS AFFECT BY PROBE INSERTION: ROWS 0"; };
						if (  $proId    == -1 )                           { die "NO ROWS AFFECT BY PROBE INSERTION: ID -1"; };
					}
		

					#push(@coord, 
#					push (@probe, [&dna2digit($MKFligSeq), &dna2digit($MKFm13Seq), $allGC, $allTm, $ligStartF, $m13StartF, $m13EndF, $strand]);
#									0						1						2		3		4			5			6		 7
					${$probe[$p]}[8] = $orgId;
					${$probe[$p]}[9] = $proId;
					delete(@{$probe[$p]}[0 .. 3]);

					if ($verbose)
					{
						#print	"ORG: $file ($orgId)\tPROB: $MKFallSeq (ID: $proId, ROWS: $proRows)\tCOOID: $cooId (ID: $cooId, ROWS: $cooRows)\tCHROM: " . ($MKFID+1) . "\n",
						#"\t$orgId, $proId, $ligStartF, $m13StartF, $m13EndF, " . ($MKFID+1) . "\n\n";
					}
				} #end foreach my probe

				while ( ! ($dbh->commit()))
				{
					print "commit failed. trying again\n";
				}

				$probeElapsed += time - $before;
			} #end if probe
			$ligStart++;
		} # END FOR MY $LIGSTART


		print "\t\t" . $p . " PROBES ADDED IN " . $probeElapsed ."s (" . int($p / ($probeElapsed+0.0001)) . " probes/s)\n" if ($p);

		my $probeSize = @probe;
		if ($probeSize)
		{
			print "\t\tADDING " . $probeSize . " COORDINATES\n";
			my $before  = time;
			my $middle  = (int(($maxLigLen / 2)+.5)); # average size of probe size
			my $lastLig = ($middle * -1) -1;
			my $nextDev = ($middle * -1) -1;
			for (my $c = 0; $c < $probeSize; $c+=$insertSize)
			{
				my $lastC = $c+($insertSize-1);
				while ($lastC >= $probeSize) { $lastC--; };

				my $values;
				for (my $cc = $c; $cc <= $lastC; $cc++)
				{
					#(idOrganism, idProbe, startLig, startM13, endM13, chromossome, derivated)
#					push (@probe, [&dna2digit($MKFligSeq), &dna2digit($MKFm13Seq), $allGC, $allTm, $ligStartF, $m13StartF, $m13EndF, $strand, orgid, probid]);
#									0						1						2		3		4			5			6			7		8		9
					my $derivated  = 0;
					my $localProbe = $probe[$cc];
					my $ligStart   = ${$localProbe}[4];
					my $strand     = ${$localProbe}[7];
					if ($strand eq "R")
					{
						if ((($lastLig-$middle) <= $ligStart) && ($lastLig >= $nextDev))
						{
							$derivated = 1;
						}
						else
						{
							$nextDev   = $ligStart-$middle;
						}
					} # end if reverse
					else
					{
						if ((($lastLig+$middle) >= $ligStart) && ($lastLig <= $nextDev))
						{
							$derivated = 1;
						}
						else
						{
							$nextDev   = $ligStart+$middle;
						}
					} # end if forward

					$lastLig = $ligStart;
					$values .= "(\'" . ${$localProbe}[8] . "\',\'" . ${$localProbe}[9] . "\',\'" . $ligStart . "\',\'" . ${$localProbe}[5] . "\',\'" . ${$localProbe}[6] . "\',\'" . $strand  . "\',\'" . ($MKFID+1) . "\',\'" . $derivated . "\'),";
#										orgid							probeid												m13start					m13end						strand					chromID					derivated
				}
				chop $values;
				my $insertCoord = $dbh->prepare("$SQLinsertCoord1$values$SQLinsertCoord2" ) or die "COULD NOT PREPARE COORDINATES QUERY: " . $DBI::errstr;
				   $insertCoord->execute() or print "COULD NOT EXECUTE COORDINATES QUERY: " . $idKeyRev[$MKFID][1] . " " . $DBI::errstr . "\n";

				$insertCoord->finish();
				my $cooId   = $insertCoord->{'mysql_insertid'};
				my $cooRows = $insertCoord->rows;

				if (( ! ($cooRows || $cooId) ) || ( ($cooRows  == 0) || ( ! (defined $cooRows))) || ( $cooId  == -1 ))
				{
					print "@"x30 . "\n";
					print "@ ORG: $file ($orgId)\n";
					print "@ \t" . join("\t", @probe) . " " . ($MKFID+1) . "\n\n";
					print "@"x30 . "\n";
					if ( ! ($cooRows || $cooId) )                      { die "NO ROWS AFFECT BY COORDINATES INSERTION: BOTH INVALID"; };
					if (   ($cooRows == 0) || ( ! (defined $cooRows))) { die "NO ROWS AFFECT BY COORDINATES INSERTION: ROWS 0"; };
					if (    $cooId   == -1 )                           { die "NO ROWS AFFECT BY COORDINATES INSERTION: ID -1"; };
				}
			} # end for my c < coords
			print "\t\t" . $probeSize . " COORDINATES ADDED IN " . (time-$before) ."s (" . int($probeSize / ((time-$before)+0.0001)) . " coords/s)\n";
			$dbh->commit();
		} # end if coords
		@probe = ();
		$revC++;
	} # end foreach my $sequence revComp(sequence)
	
	print "\tSEQUENCE $MKFfile "  . $idKeyRev[$MKFID][1] . " ANALIZED IN " . (time - $beforeGeneral)      . "s\n";
	print "\t$countValAll PROBES GENERATED ("  . int($countValAll / ((time-$beforeGeneral)+0.0001))       ."probes/s)\n";
	print "\t$MKFsequenceLength BP ANALYSED (" . int($MKFsequenceLength / ((time-$beforeGeneral)+0.0001)) ."bp/s)\n";

	$dbh->commit();
	$dbh->disconnect();
	return undef;
}


sub getSpeed
{
	my $currentT    = time;
	my $elapsedT    = $currentT - $lastTime;
#	my $speed       = int($centimo / $elapsedT);
	my $elapsedVal  = $countValAll - $lastVal;
	my $valSpeed    = int($elapsedVal / ($elapsedT+0.000001));
	my $valRelSpeed = int($elapsedVal / ($tElapsed+0.000001));

	my $tp1000C     = int($tElapsed * (100000 / $centimo));
	my $tp1000V     = int($tElapsed * (100000 / $elapsedVal));

	my $return      = "\t\t\t$valSpeed"    . " valid probes (actual queries)/s\n";
	   $return     .= "\t\t\t$valRelSpeed" . " valid probes (actual queries) /seconds (quering seconds)\n";
	   $return     .= "\t\t\t$tElapsed"    . " s for $centimo (gross) / $elapsedVal (valids) probes\n";
	   $return     .= "\t\t\t$tp1000C"     . " s for 100000 (gross) probes\n";
	   $return     .= "\t\t\t$tp1000V"     . " s for 100000 (valid) probes\n";

	$lastTime       = $currentT;
	$lastVal        = $countValAll;
	$tElapsed       = 0;
	return $return;
}

sub getFasta
{
	my $file  = $_[0];
	my @seq;
	my @tmpSeq;
	my $count = 0;
	my $ID;
	my $sequence;
	my @threads;

	open FILE, "<$file" or die "COULD NOT OPEN FASTA FILE $file: $!\n";
	while (<FILE>)
	{
		chomp $_;
		$count++;
		if ($_)
		{
			if (substr($_,0,1) eq '>')
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
					&printLog(0, "MAKING FRAGMENTS FOR $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
					threads->new(\&mkFragments, ($file, $ID, $sequence));
					$totalSeq++;
				}

				$ID     = substr($_, 1);
				$_      = substr($_, 1);
				if ($ID =~ /(\S+)\s/) {$ID = $1;};
				$ID =~ tr/ /_/;
				$ID =~ tr/\//_/;
				$ID =~ tr/a-zA-Z0-9_/_/cd;

				my $key;
				if (defined $idKey{$ID})
				{
					$key = $idKey{$ID}
				}
				else
				{
					$key               = @idKeyRev;
					$idKey{$ID}        = $key;
					$idKeyRev[$key][0] = $ID;
					$idKeyRev[$key][1] = $_;
				}
				$ID = $key;

				$sequence = "";
			}
			else
			{
				$_ =~ tr/[A|C|T|G|N|a|c|t|g|n]//cd;
				$_ = uc($_);
# 				print "$_\n";
				if ((defined $ID) && ($ID ne "") && ($ID ne " "))
				{
					$sequence .= $_;
				}
			}
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
		&printLog(0, "MAKING FRAGMENTS FOR $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
		threads->new(\&mkFragments, ($file, $ID, $sequence));
		$totalSeq++;
	}

	$runned = 1;
	print "$count LINES LOADED\n";

	close FILE;
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
sub revComp
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
	print $text if ( $verbo <= $log );

	if ($verbo <= $log)
	{
		print LOG time . "\t$text";
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













sub digit2dna
{
	my $seq  = $_[0];
	my $lengthSeq = length($seq);
	my $outSeq;
# 	print "$seq (" . length($seq) . ") > ";
	my $extra = "";
	if ( $seq =~ /([^a|c|t|g|A|C|T|G]*)([a|c|t|g|A|C|T|G]*)/)
	{
		$seq   = $1;
		$extra = uc($2);
	}

	if ($lengthSeq != length("$seq$extra")) { die "ERROR UMPACKING DNA"; };

#	print "$seq (" . length($seq) . ") + $extra (" . length($extra) . ") >> ";

	for (my $s = 0; $s < length($seq); $s+=1)
	{
		my $subSeq  = substr($seq, $s, 1);
		$outSeq    .= $dnaKey[$CODE_TO_DIGIT{$subSeq}];
	}

# 	print "$outSeq (" . length($outSeq) . ") -> ";
	$outSeq .= $extra;
# 	print "$outSeq (" . length($outSeq) . ")\n\n";
	return $outSeq;
}

sub dna2digit
{
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
		$outPut     .= $DIGIT_TO_CODE[$keyDna{$subInput}];
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


sub loadVariables
{
	foreach my $st ("A", "C", "G", "T")
	{
	foreach my $nd ("A", "C", "G", "T")
	{
	foreach my $rd ("A", "C", "G", "T")
	{
		push(@dnaKey, "$st$nd$rd");
	}
	}
	}

	@DIGIT_TO_CODE = qw (0 1 2 3 4 5 6 7 8 9 b d e f h i j k l m n o p q r s u v w x y z B D E F H I J K L M N O P Q R S U V W X Y Z / - = + ] [ : > < . ? );
	#  COUNT             1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 
	#                    1                 10                  20        25        30        35        40  42              50                  60        65
	#  INDEX             0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 
	#                    0                   10                  20        25        30        35        40  42              50                  60      64
	for (my $k = 0; $k < @dnaKey; $k++)
	{
		$keyDna{$dnaKey[$k]} = $k;
	}

	for (my $i = 0; $i < @DIGIT_TO_CODE; $i++)
	{
		$CODE_TO_DIGIT{$DIGIT_TO_CODE[$i]} = $i;
	}
}


1;

