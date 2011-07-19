#!/usr/bin/perl -w
use strict;
use DBI;
use lib "./filters";
use complexity;
use folding;
use similarity;
use dnaCode;
use blast;

use threads;
use threads::shared;
use threads 'exit'=>'threads_only';

#############################
### SETUP
#############################
my $originalView  = "complete"; #orginal information
my $originalTable = "t_originalFinal"; #intermediate destination
my $finalTable    = "finalProbes"; # final destination
my $reuse         = undef; # table to reuse. undef to create a new table
my $orderBy       = "ORDER BY idOrganism, chromossome, startLig"; # order by to final table

my $database      = 'probe';
my $limit         = 20;
my $host          = 'localhost'; 
my $user          = 'probe';
my $pw            = '';
my $batchInsertions = 10_000; # number of batch insertions

#	COLUMN NAME		TYPE	SIZE	OPTIONS	[0=1ST AUTOMATIC 1=2ND MANUAL RUN]
my @newColumns = 
(
	["Similarity1",    "INT",   "1", "UNSIGNED", 1],
	["Similarity2",    "INT",   "1", "UNSIGNED", 1],
	["Similarity3",    "INT",   "1", "UNSIGNED", 1],
	["Complexity",     "INT",   "1", "UNSIGNED", 0],
	["Folding",        "INT",   "3", "UNSIGNED", 0],
	["FoldingLig",     "INT",   "3", "UNSIGNED", 0],
	["FoldingM13",     "INT",   "3", "UNSIGNED", 0],
	["AnalysisResult", "INT",   "4", "UNSIGNED", 0]
);
#	["Ligant",         "CHAR", "20", "BINARY",   1],
#	["LigantUnique",   "INT",   "1", "UNSIGNED", 1]

my $maxThreads  = 3;
my $napTime     = 1;
my $statVerbose = 0;


#############################
### INITIATION
#############################
my $addColumn   = "";
my $dropColumn  = "";
my $insertInto  = "";
my $insertExtra = "";
#my $updateFirstFh;
#my $updateExtraFh;
my $countRow = 0;
my ($indLS, $indMS, $indL, $indM, $indS, $indLg, $indOrg, $indId);
my %ligantSeen;
my $threadCount = 0;
#my @result;
$batchInsertions -= 1;

my %newColumnIndex;
foreach my $info (@newColumns)
{
	my $name        = ${$info}[0];
	my $type        = ${$info}[1];
	my $size        = ${$info}[2];
	my $extra       = ${$info}[3];
	my $secondRound = ${$info}[4];

	$addColumn .= ", ADD COLUMN $name $type";
	$addColumn .= " ($size)" if $size;
	$addColumn .= " $extra"  if $extra;
	$dropColumn .= "," if ($dropColumn);
	$dropColumn .= " DROP COLUMN $name";

	$newColumnIndex{$name} = undef;

	if ( ! $secondRound )
	{
		$insertInto .=  ", " if ($insertInto ne "");
		$insertInto .=  "$name = ?";
	}
}

my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
my $timeStamp = sprintf("%04d%02d%02d%02d%02d", (1900+$year), ($mon+1), $mday, $hour, $min);
$originalTable .= $timeStamp;
if ($reuse)
{
	$originalTable = $reuse;
}


#############################
### SQL STATEMENTS
#############################
my $createQuery              = "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM \`$database\`.\`$originalView\` GROUP BY sequenceM13 HAVING count(sequenceM13) = 1) as Tm13 GROUP BY ligant HAVING count(ligant) = 1) as Tligant GROUP BY sequenceLig HAVING count(sequenceLig) = 1) AS Tlig  GROUP BY sequence HAVING count(sequence) = 1";
my $commandCreateTable       = "CREATE TABLE \`$database\`.\`$originalTable\` ENGINE InnoDB $createQuery";
my $commandAddColumn         = "ALTER  TABLE \`$database\`.\`$originalTable\` ADD COLUMN Id INT UNSIGNED NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (Id)$addColumn"; 

my $createQueryFinal         = "SELECT * FROM \`$database\`.\`$originalTable\`";
if ($orderBy) { $createQueryFinal .= "$orderBy"; };
my $commandDropFinalTable    = "DROP TABLE IF EXISTS \`$database\`.\`$finalTable\`";
my $commandCreateFinalTable  = "CREATE TABLE \`$database\`.\`$finalTable\`  ENGINE InnoDB $createQueryFinal";
my $commandDropColumn        = "ALTER  TABLE \`$database\`.\`$finalTable\`  ADD PRIMARY KEY (Id), $dropColumn"; 

my $commandGetAllResults     = "SELECT * FROM \`$database\`.\`$originalTable\`";
my $commandGetSim1Results    = "SELECT * FROM \`$database\`.\`$originalTable\` WHERE Similarity1 IS NULL";
my $commandGetCompResults    = "SELECT * FROM \`$database\`.\`$originalTable\` WHERE Similarity1 IS NULL AND (AnalysisResult = 0 OR AnalysisResult IS NULL)";
my $commandGetSim2Results    = "SELECT * FROM \`$database\`.\`$originalTable\` WHERE Similarity1 IS NULL AND (AnalysisResult = 0 OR AnalysisResult IS NULL) AND Similarity2 IS NULL";
my $commandGetSim3Results    = "SELECT * FROM \`$database\`.\`$originalTable\` WHERE Similarity1 IS NULL AND (AnalysisResult = 0 OR AnalysisResult IS NULL) AND Similarity2 IS NULL AND Similarity3 IS NULL";

my $commandUpdateSimilarity1 = "UPDATE \`$database\`.\`$originalTable\` SET Similarity1 = ? WHERE Id = ?";
my $commandUpdateComplexity  = "UPDATE \`$database\`.\`$originalTable\` SET $insertInto WHERE Id = ?";
my $commandUpdateSimilarity2 = "UPDATE \`$database\`.\`$originalTable\` SET Similarity2 = ? WHERE Id = ?";
my $commandUpdateSimilarity3 = "UPDATE \`$database\`.\`$originalTable\` SET Similarity3 = ? WHERE Id = ?";
my $commandUpdateLigants     = "UPDATE \`$database\`.\`$originalTable\` SET ligant = ? WHERE Id = ?";

#############################
### PROGRAM
#############################
if ( ! $reuse )
{
	&sthInsertCreate($commandCreateTable, $commandAddColumn); # create table out of result view
}
&sthAnalizeStat($commandGetAllResults);	# get result table
&sthAnalyzeFirst();	# analyze anything that can be done row by row.
					# update the table at the end automatically
					# threaded


#&sthAnalyzeExtra(); # analyze anything that needs extra data handling
					# the update must be done individually
					# any threading must be done individually

&sthInsertCreate($commandDropFinalTable, $commandCreateFinalTable, $commandDropColumn); # create final table out of intermediate table
print "SELECTION DONE. CONGRATS\n";

#######################################
####### CORE FUNCTIONS
#######################################
sub sthInsertCreate
{
	my @commands = @_;
	my $dbhI = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
		 or die "INSERT :: COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	print "INSERT :: CREATING MYSQL RESULT TABLE\n";

	foreach my $command (@commands)
	{
		$dbhI->do($command);
	}

	print "INSERT :: TIMESTAMP : $timeStamp\n";
	$dbhI->commit();
	$dbhI->disconnect();
}


sub sthAnalyzeFirst
{
	print "ANALIZE FIRST :: STARTING FIRST STEP OF ANALYSIS\n";

	&sthAnalizeSimilarity1($commandGetAllResults, $commandUpdateSimilarity1);

	&sthAnalizeFoldComplexity($commandGetSim1Results, $commandUpdateComplexity);

	&sthAnalizeSimilarity2($commandGetCompResults, $commandUpdateSimilarity2);

#	&sthAnalizeSimilarity3($commandGetSim2Results, $commandGetAllResults, $commandUpdateSimilarity3);

	print "ANALIZE FIRST :: FIRST STEP OF ANALYSIS DONE\n";

}


sub sthAnalyzeExtra
{
	print "ANALIZE EXTRA :: STARTING SECOND STEP OF ANALYSIS\n";

	&sthGenerateLigants();
	&analyzeLigants();

	print "ANALIZE EXTRA :: SECOND STEP OF ANALYSIS DONE\n";
}







#######################################
####### SQL STATISTICAL/SETUP FUNCTIONS
#######################################
sub sthAnalizeStat
{
	my $command = $_[0];
	print "_"x2, "STAT :: RETRIEVING TABLE INFORMATION\n";
	print "_"x4, "STAT :: RETRIEVING RESULT\n";
	my $dbhS = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
		 or die "STAT :: COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $sthS = $dbhS->prepare($command);
	$sthS->execute();
	print "_"x4, "STAT :: RESULT RETRIEVED SUCCESSIFULLY\n";

	my $numOfFields = $sthS->{NUM_OF_FIELDS};


	my @fields;
	for (my $f = 0; $f < $numOfFields; $f++)
	{
		my $fieldName = $sthS->{NAME}->[$f];
		push(@fields, $fieldName);
	}

	for (my $i = 0; $i < @fields; $i++)
	{ 
		my $field = $fields[$i];
		if ($field eq "startLig")     { $indLS  = $i; }
		if ($field eq "startM13")     { $indMS  = $i; }
		if ($field eq "sequenceLig")  { $indL   = $i; }
		if ($field eq "sequenceM13")  { $indM   = $i; }
		if ($field eq "sequence")     { $indS   = $i; }
		if ($field eq "ligant")       { $indLg  = $i; }
		if ($field eq "idOrganism")   { $indOrg = $i; }
		if ($field eq "Id")           { $indId  = $i; }
		if (exists $newColumnIndex{$field}) {$newColumnIndex{$field} = $i};
	}

	my $maxLen = 9;
	foreach my $col (keys %newColumnIndex)
	{
		$maxLen = length($col) if (length($col) > $maxLen);
	}

	if ( ! ((defined $indId) && (defined $indOrg) && (defined $indM) && (defined $indL) && (defined $indMS) && (defined $indLS))) { die "COULD NOT OBTAIN COLUMNS INDEX. CHECK COLUMN NAMES"; };

	if ($statVerbose)
	{
		print "_"x4, "STAT :: TOTAL COLUMNS : ", (scalar @fields) , "\n";
		print "\tOLD\n";
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "LIG START", $indLS;
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "M13 START", $indMS;
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "LIG SEQ",   $indL;
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "M13 SEQ",   $indM;
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "SEQ SEQ",   $indS;
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "LIGA SEQ",  $indLg;
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "ORGANISM",  $indOrg;
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "ID",        $indId;
		printf "\tNEW\n";
	}
	foreach my $col (sort keys %newColumnIndex)
	{
		if ($statVerbose)
		{		
			printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", uc($col), $newColumnIndex{$col};
		}
		if ( ! (defined $newColumnIndex{$col})) { die "NEW COLUMN $col NOT FOUND\n"; };
	}
	
	die "STAT :: PROBLEM RETRIEVING TABLE $database", $sthS->errstr() ,"\n" if $sthS->err();

	$sthS->finish();
	$dbhS->commit();
	$dbhS->disconnect();
	print "_"x2, "STAT :: TABLE INFORMATION RETRIEVED\n\n\n";
}



#######################################
####### SEQUENCES ANALYSIS
#######################################

#################
####### SIMILARITY
#################
sub sthAnalizeSimilarity1
{
	my $commandGet    = $_[0];
	my $commandUpdate = $_[1];
	print "_"x2, "SIMILARITY 1 :: STARTING SIMILARITY ANALYSIS 1\n";
	print "_"x4, "SIMILARITY 1 :: RETRIEVING RESULT\n";
	my $dbh1 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
		 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $sth1 = $dbh1->prepare($commandGet);
	$sth1->execute();
	print "_"x6, "SIMILARITY 1 :: ", $sth1->rows, " RESULTS RETRIEVED SUCCESSIFULLY\n";

	   $countRow  = 0;
	my $startTime   = time;

	my @listLig;
	my @listM13;
	my @listSeq;
	my @listLiga;

	while(my $row = $sth1->fetchrow_arrayref) 
	{
		$countRow++;
		print "_"x4, "SIMILARITY 1 :: ACQUIRING ROW # $countRow\n" if ( ! ($countRow % 25_000));
		my @row     = @{$row};
		my $org     = $row[$indOrg];
		my $seqLig  = $row[$indL];
		my $seqM13  = $row[$indM];
		my $seqSeq  = $row[$indS];
		my $seqLiga = $row[$indLg];
		my $rowNum  = $row[$indId];

		$listLig[$rowNum]  = $seqLig;
		$listM13[$rowNum]  = $seqM13;
		$listSeq[$rowNum]  = $seqSeq;
		$listLiga[$rowNum] = $seqLiga;
	}

	print "_"x4, "SIMILARITY 1 :: DATA GATHERED TO SIMILARITY ANALYSIS 1: ", (int((time - $startTime)+.5)), "s\n";
#####################
	&analizeSimilarity1($commandUpdate, \@listLig, \@listM13, \@listSeq, \@listLiga);
#####################
	$sth1->finish();
	$dbh1->commit();
	$dbh1->disconnect();
	print "_"x2, "SIMILARITY 1 :: SIMILARITY ANALYSIS 1 COMPLETED\n\n\n";
}


sub sthAnalizeSimilarity2
{
	my $commandGet    = $_[0];
	my $commandUpdate = $_[1];
	print "_"x2, "SIMILARITY 2 :: STARTING SIMILARITY ANALYSIS 2\n";
	print "_"x4, "SIMILARITY 2 :: RETRIEVING RESULT\n";
	my $dbh2 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
		 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $sth2 = $dbh2->prepare($commandGet);
	$sth2->execute();
	print "_"x6, "SIMILARITY 2 :: ", $sth2->rows, " RESULT RETRIEVED SUCCESSIFULLY\n";

	   $countRow  = 0;
	my $startTime   = time;

	my @listLig;
	my @listM13;
	my @listSeq;
	my @listLiga;

	while(my $row = $sth2->fetchrow_arrayref) 
	{
		$countRow++;
		print "_"x4, "SIMILARITY 2 :: ACQUIRING ROW # $countRow\n" if ( ! ($countRow % 25_000));
		my @row     = @{$row};
		my $org     = $row[$indOrg];
		my $seqLig  = $row[$indL];
		my $seqM13  = $row[$indM];
		my $seqSeq  = $row[$indS];
		my $seqLiga = $row[$indLg];
		my $rowNum  = $row[$indId];

		$listLig[$rowNum]  = $seqLig;
		$listM13[$rowNum]  = $seqM13;
		$listSeq[$rowNum]  = $seqSeq;
		$listLiga[$rowNum] = $seqLiga;
	}

	print "_"x4, "SIMILARITY 2 :: DATA GATHERED TO SIMILARITY ANALYSIS 2: ", (int((time - $startTime)+.5)), "s\n";
#####################
	&analizeSimilarity2($commandUpdate, \@listLig, \@listM13, \@listSeq, \@listLiga);
#####################
	$sth2->finish();
	$dbh2->commit();
	$dbh2->disconnect();
	print "_"x2, "SIMILARITY 2 :: SIMILARITY ANALYSIS 2 COMPLETED\n\n\n";
}



sub sthAnalizeSimilarity3
{
	my $commandGetValid = $_[0];
	my $commandGetAll   = $_[1];
	my $commandUpdate   = $_[2];

	print "_"x2, "SIMILARITY 3 :: STARTING SIMILARITY ANALYSIS 3\n";
	print "_"x4, "SIMILARITY 3 :: RETRIEVING RESULT\n";

	my $dbh3 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
		 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

	my $sth3V = $dbh3->prepare($commandGetValid);
	$sth3V->execute();
	my $rowsV = $sth3V->rows;
	print "_"x6, "SIMILARITY 3 :: ",$rowsV, " RESULT RETRIEVED SUCCESSIFULLY\n";

	my $sth3A = $dbh3->prepare($commandGetAll);
	$sth3A->execute();
	my $rowsA = $sth3A->rows;
	print "_"x6, "SIMILARITY 3 :: ",$rowsA, " RESULTS RETRIEVED SUCCESSIFULLY\n";



	my $startTime = time;

	my @listLigV;
	my @listM13V;
	my @listSeqV;
	my @listLigaV;

	my @listLigA;
	my @listM13A;
	my @listSeqA;
	my @listLigaA;

    $countRow  = 0;
	while(my $row = $sth3V->fetchrow_arrayref) 
	{
		$countRow++;
		print "_"x4, "SIMILARITY 3 :: ACQUIRING VALID ROW # $countRow\n" if ( ! ($countRow % (int($rowsV / 5))));
		my @row     = @{$row};
		my $org     = $row[$indOrg];
		my $seqLig  = $row[$indL];
		my $seqM13  = $row[$indM];
		my $seqSeq  = $row[$indS];
		my $seqLiga = $row[$indLg];
		my $rowNum  = $row[$indId];

		$listLigV[$rowNum]  = $seqLig;
		$listM13V[$rowNum]  = $seqM13;
		$listSeqV[$rowNum]  = $seqSeq;
		$listLigaV[$rowNum] = $seqLiga;
	}

    $countRow  = 0;
	while(my $row = $sth3A->fetchrow_arrayref) 
	{
		$countRow++;
		print "_"x4, "SIMILARITY 3 :: ACQUIRING ALL ROW # $countRow\n" if ( ! ($countRow % (int($rowsA / 5))));
		my @row     = @{$row};
		my $org     = $row[$indOrg];
		my $seqLig  = $row[$indL];
		my $seqM13  = $row[$indM];
		my $seqSeq  = $row[$indS];
		my $seqLiga = $row[$indLg];
		my $rowNum  = $row[$indId];

		$listLigA[$rowNum]  = $seqLig;
		$listM13A[$rowNum]  = $seqM13;
		$listSeqA[$rowNum]  = $seqSeq;
		$listLigaA[$rowNum] = $seqLiga;
	}

	print "_"x4, "SIMILARITY 3 :: DATA GATHERED TO SIMILARITY ANALYSIS 3: ", (int((time - $startTime)+.5)), "s\n";
#####################
	&analizeSimilarity3($commandUpdate, \@listLigV, \@listLigA, \@listM13V, \@listM13A, \@listSeqV, \@listSeqA, \@listLigaV, \@listLigaA);
#####################
	$sth3V->finish();
	$sth3A->finish();
	$dbh3->commit();
	$dbh3->disconnect();
	print "_"x2, "SIMILARITY 3 :: SIMILARITY ANALYSIS 3 COMPLETED\n\n\n";
}


sub analizeSimilarity1
{
	my $commandUpdate = $_[0];

	my $Gresult  = [];

	my $startTime = time;

#####################
	$Gresult = &similarity::quasiBlast($Gresult, @_[1 .. (scalar @_ - 1)]);
#####################

	my $resultValid   = 0;
	my $resultInValid = 0;
	for (my $p = 0; $p < @{$Gresult}; $p++)
	{
		my $resultSum = $Gresult->[$p];

		if (defined $resultSum)
		{
			if ($resultSum == "-1")
			{
				$resultSum     = undef;
				$Gresult->[$p] = undef;
				$resultValid++;
			}
			else
			{
				$resultInValid++;
			}
		}
		else
		{
			$resultValid++;
		}
	}

	print "_"x4, "SIMILARITY 1 :: VALID: ", $resultValid," INVALID: ", $resultInValid,"\n";


	# 1=not ok null=OK

	my $queryStart = time;
	my $ldbh1 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $countResults = 0;
	for (my $r = 0; $r < @{$Gresult}; $r++)
	{
		if (defined $Gresult->[$r])
		{
			#print join("\t", @{$result}) . "\n";
			my $updateFirstFh = $ldbh1->prepare_cached($commandUpdate);
			   $updateFirstFh->execute($Gresult->[$r], $r);
			   $updateFirstFh->finish();
			$countResults++;
		}
	}
	$ldbh1->commit();
	$ldbh1->disconnect();

	print "_"x4, "SIMILARITY 1 :: UPDATE QUERY TIME : " , (time-$queryStart) , "s FOR ", $countResults," QUERIES\n";
	print "_"x4, "SIMILARITY 1 :: TOTAL TIME : ", (int((time - $startTime)+.5)), "s\n";
	return undef;
}


sub analizeSimilarity2
{
	my $commandUpdate = $_[0];

	my $Gresult  = [];

	my $startTime = time;

#####################
	$Gresult  = &similarity::almostBlast($Gresult, @_[1 .. (scalar @_ - 1)]);
#####################
	my $h = 0;
	for (my $g = 0; $g <@{$Gresult}; $g++)
	{
		if (defined $Gresult->[$g]) { $h++ }
	}
	print "_"x4, "SIMILARITY 2 :: AFTER ALMOSTBLAST: $h INVALIDS\n\n";


#####################
	$Gresult = &blast::blastNWIterate($Gresult, @_[1 .. (scalar @_ - 1)]);
#####################
	$h = 0;
	for (my $g = 0; $g <@{$Gresult}; $g++)
	{
		if (defined $Gresult->[$g]) { $h++ }
	}
	print "_"x4, "SIMILARITY 2 :: AFTER BLASTNW: $h INVALIDS\n\n";




	my $resultValid   = 0;
	my $resultInValid = 0;
	for (my $p = 0; $p < @{$Gresult}; $p++)
	{
		my $resultSum = $Gresult->[$p];

		if (defined $resultSum)
		{
			if ($resultSum == "-1")
			{
				$resultSum     = undef;
				$Gresult->[$p] = undef;
				$resultValid++;
			}
			else
			{
				$resultInValid++;
			}
		}
		else
		{
			$resultValid++;
		}
	}

	print "_"x4, "SIMILARITY 2 :: VALID: ", $resultValid," INVALID: ", $resultInValid,"\n";

	# 1=not ok null=ok

	my $queryStart = time;
	my $ldbh2 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $countResults = 0;
	for (my $r = 0; $r < @{$Gresult}; $r++)
	{
		if (defined $Gresult->[$r])
		{
			#print join("\t", @{$result}) . "\n";
			my $updateFirstFh = $ldbh2->prepare_cached($commandUpdate);
			   $updateFirstFh->execute($Gresult->[$r], $r);
			   $updateFirstFh->finish();
			$countResults++;
		}
	}
	$ldbh2->commit();
	$ldbh2->disconnect();

	print "_"x4, "SIMILARITY 2 :: UPDATE QUERY TIME : " , (time-$queryStart) , "s FOR ",$countResults," QUERIES\n";
	print "_"x4, "SIMILARITY 2 :: TOTAL TIME : ", (int((time - $startTime)+.5)), "s\n";
	return undef;
}



sub analizeSimilarity3
{
	my $commandUpdate = $_[0];

	my $Gresult  = [];

	my $startTime = time;

#####################
	$Gresult = &blast::blastNWIterateTwo($Gresult, @_[1 .. (scalar @_ -1)]);
#####################
	my $h = 0;
	for (my $g = 0; $g <@{$Gresult}; $g++)
	{
		if (defined $Gresult->[$g]) { $h++ }
	}
	print "SIMILARITY 3 :: AFTER BLASTNWTWO : $h INVALIDS\n";


	my $resultValid   = 0;
	my $resultInValid = 0;
	for (my $p = 0; $p < @{$Gresult}; $p++)
	{
		my $resultSum = $Gresult->[$p];

		if (defined $resultSum)
		{
			if ($resultSum == "-1")
			{
				$resultSum     = undef;
				$Gresult->[$p] = undef;
				$resultValid++;
			}
			else
			{
				$resultInValid++;
			}
		}
		else
		{
			#$resultValid++;
		}
	}

	print "_"x4, "SIMILARITY 3 :: VALID: ", $resultValid," INVALID: ", $resultInValid,"\n";

	# 1=not ok null=ok


	my $queryStart = time;
	my $ldbh3 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $countResults = 0;
	for (my $r = 0; $r < @{$Gresult}; $r++)
	{
		if (defined $Gresult->[$r])
		{
			#print join("\t", @{$result}) . "\n";
			my $updateFirstFh = $ldbh3->prepare_cached($commandUpdate);
			   $updateFirstFh->execute($Gresult->[$r], $r);
			   $updateFirstFh->finish();
			$countResults++;
		}
	}
	$ldbh3->commit();
	$ldbh3->disconnect();

	print "_"x4, "SIMILARITY 3 :: UPDATE QUERY TIME : " , (time-$queryStart) , "s FOR ",$countResults," QUERIES\n";
	print "_"x4, "SIMILARITY 3 :: TOTAL TIME : ", (int((time - $startTime)+.5)), "s\n";
	return undef;
}




#################
####### FOLD COMPLEXITY
#################
sub sthAnalizeFoldComplexity
{
	my $commandGet    = $_[0];
	my $commandUpdate = $_[1];
	print "_"x2, "COMPLEXITY :: STARTING FOLD COMPLEXITY ANALYSIS\n";
	print "_"x4, "COMPLEXITY :: RETRIEVING RESULT\n";
	my $ldbhC = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $sthC = $ldbhC->prepare($commandGet);
	$sthC->execute();
	print "_"x6, "COMPLEXITY :: ", $sthC->rows, " RESULTS RETRIEVED SUCCESSIFULLY\n";
	my $rc = $sthC->rows;
	my $LbatchInsertions = $batchInsertions;
	if ($LbatchInsertions > ($rc/$maxThreads))
	{
		$LbatchInsertions = int($rc/$maxThreads);
	}

	   $countRow  = 0;
	my @batch;


	while(my $row = $sthC->fetchrow_arrayref) 
	{
		$countRow++;
		if ( (scalar @batch) == $LbatchInsertions )
		{
			my @row = @{$row};
			push(@batch, \@row);
			print "\tCOMPLEXITY :: ANALYZING ROW # $countRow\n";
			while (threads->list(threads::running) > ($maxThreads-1))
			{
				sleep($napTime); 
			}

			foreach my $thr (threads->list(threads::joinable))
			{
				$thr->join();
			}
			print "\t\tCOMPLEXITY :: STARTING THREAD $threadCount ($countRow)\n";
			threads->new(\&analizeFoldComplexityRow, (\@batch, $threadCount, $commandUpdate));
			$threadCount++;
			@batch = ();
		}
		else
		{
			my @row = @{$row};
			push(@batch, \@row);
		};
	}
	print "\t\tCOMPLEXITY :: STARTING LAST THREAD $threadCount\n";
	threads->new(\&analizeFoldComplexityRow, (\@batch, $threadCount, $commandUpdate));
	@batch = ();



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

	$sthC->finish();
	$ldbhC->commit();
	$ldbhC->disconnect();
	print "_"x2, "COMPLEXITY :: FOLD COMPLEXITY ANALYSIS COMPLETED\n\n\n";
}




sub analizeFoldComplexityRow
{
	my $startTime   = time;
	my @batch       = @{$_[0]};
	my $innerThread =   $_[1];
	my $commandUpdate = $_[2];
	my @results;

	print "\t\tCOMPLEXITY :: THREAD $innerThread RUNNING WITH " . (scalar @batch) . " INPUTS\n";
	foreach my $row (@batch)
	{
		my @row      = @{$row};
		my $ligStart = $row[$indLS];
		my $m13Start = $row[$indMS];
		my $org      = $row[$indOrg];
		my $seqLig   = $row[$indL];
		my $seqM13   = $row[$indM];
		my $rowNum   = $row[$indId];
		if ( ! defined $rowNum ) { die "ROWNUM NOT DEFINED"; };

#		my $seq      = $row[$newColumnIndex{"sequence"}];
#		my $ligant   = $row[$newColumnIndex{"ligant"}];

#		print "BEFORE $seqLig $seqM13\n";
		$seqLig    = &dnaCode::digit2dna($seqLig);
		$seqM13    = &dnaCode::digit2dna($seqM13);
		my $seq    = "$seqLig$seqM13";
#		my $ligant = substr($seqLig, -10) . substr($seqM13, 0, 10);

#		print "AFTER\n$seqLig.$seqM13\n$seq\n$ligant\n";

		#print join("\t", @row[0 .. 15]) . " > $rowNum\n";

		my $result = 0;

		my $m13StartRel = $m13Start - $ligStart;
		my $ligStartRel = 0;

		my $complexity  = &complexity::HasMasked($seq);
		if ($complexity) { $result += 1; };
		if ( ! defined $complexity) { die "COMPLEXITY RETURNED NULL"; };

		my $seqFold = &folding::checkFolding($seq);
		my $ligFold = &folding::checkFolding($seqLig);
		my $m13Fold = &folding::checkFolding($seqM13);

		if ( ! defined $seqFold) { die "seqFOLD RETURNED NULL"; };
		if ( ! defined $ligFold) { die "ligFOLD RETURNED NULL"; };
		if ( ! defined $m13Fold) { die "m13FOLD RETURNED NULL"; };

		if ($seqFold) { $result += 2};
		if ($ligFold) { $result += 4};
		if ($m13Fold) { $result += 8};

		if ($result > 16)
		{
			print "LIGSTART: $ligStart M13START: $m13Start\n$seq\n";
#			print " "x($m13StartRel-10) . "$ligant\n$seqLig.$seqM13\n";
			print "RESULT     : $result\n";
			print "COMPLEXITY : $complexity\n";
			print "FOLDING    : LIG=$ligFold, M13=$m13Fold, SEQ=$seqFold\n\n";
		}

		if ( ! defined $result) { die "RESULT RETURNED NULL"; };
		my @newData = ($complexity, $seqFold, $ligFold, $m13Fold, $result, $rowNum);
		push(@results, \@newData);
	} # end foreach my row



	my $queryStart = time;
	my $ldbhAC = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $countResults = 0;
	foreach my $result (@results)
	{
#		print join("\t", @{$result}) . "\n";
		my $updateFirstFh = $ldbhAC->prepare_cached($commandUpdate);
		   $updateFirstFh->execute(@{$result});
		   $updateFirstFh->finish();
		$countResults++;
	}
	$ldbhAC->commit();
	$ldbhAC->disconnect();

	print "\t\t\tCOMPLEXITY :: UPDATE QUERY FOR THREAD $innerThread TOOK " . (time-$queryStart) . "s FOR $countResults QUERIES\n";
	print "\t\tCOMPLEXITY :: THREAD $innerThread HAS FINISHED (" . (time-$startTime) . "s)\n";
	return undef;
}




















#################
####### LIGANT FUNCTIONS
#################
#NOT NEEDED
sub sthGenerateLigants
{
	my $ldbhGL = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $sthL      = $ldbhGL->prepare_cached($commandGetSim2Results);
	   $countRow  = 0;
	my @batch;

	while(my $row = $sthL->fetchrow_arrayref) 
	{
		$countRow++;
		if ( (scalar @batch) == $batchInsertions )
		{
			my @row = @{$row};
			push(@batch, \@row);
			print "\tANALYZING ROW # $countRow\n";

			&insertLigants(\@batch);
			@batch = ();
		}
		else
		{
			my @row = @{$row};
			push(@batch, \@row);
		};
	}
	&insertLigants(\@batch);
	@batch = ();
	$sthL->finish();
	$ldbhGL->commit();
	$ldbhGL->disconnect();
}

#NOT NEEDED
sub insertLigants
{
	my $startTime   = time;
	my @batch       = @{$_[0]};
	my @results;

	print "\t\tUNPACKING " . (scalar @batch) . " INPUTS\n";
	foreach my $row (@batch)
	{
		my @row      = @{$row};
		my $seqLig   = $row[$indL];
		my $seqM13   = $row[$indM];
		my $rowNum   = $row[$indId];
		if ( ! defined $rowNum ) { die "ROWNUM NOT DEFINED"; };

#		my $seq      = $row[$newColumnIndex{"sequence"}];
#		my $ligant   = $row[$newColumnIndex{"ligant"}];

#		print "BEFORE $seqLig $seqM13\n";
		$seqLig    = &dnaCode::digit2dna($seqLig);
		$seqM13    = &dnaCode::digit2dna($seqM13);
		my $seq    = "$seqLig$seqM13";
		my $ligant = substr($seqLig, -10) . substr($seqM13, 0, 10);
#		$ligant    = &dna2digit($ligant);

#		print "AFTER\n$seqLig.$seqM13\n$seq\n$ligant\n";

		#print join("\t", @row[0 .. 15]) . " > $rowNum\n";

		my @newData = ($ligant, $rowNum);
		push(@results, \@newData);
	} # end foreach my row



	my $queryStart = time;
	my $ldbhL = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $countResults = 0;
	foreach my $result (@results)
	{
#		print join("\t", @{$result}) . "\n";
		my $updateFirstFh = $ldbhL->prepare_cached($commandUpdateLigants);
		   $updateFirstFh->execute(@{$result});
		   $updateFirstFh->finish();
		$countResults++;
	}
	$ldbhL->commit();
	$ldbhL->disconnect();

	print "\t\t\tUPDATE QUERY TOOK " . (time-$queryStart) . "s FOR $countResults QUERIES\n";
	return undef;
}

#TO FIX
sub analyzeLigants
{
	my $commandUpdateExtra = "UPDATE \`probe\`.\`$originalTable\` SET LigantUnique = ?, AnalysisResult = (AnalysisResult + ?) WHERE Id = ?";
	my $commandGetLigant   = "SELECT Id, Ligant, nameOrganism FROM $originalTable";
	my %ligantSeen;



	print "\tANALYZING LIGANTS\n";	
	my $ligantsTime = time;
	my $queryStart  = time;	
	my $ldbhAL      = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0}) or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $resultFh    = $ldbhAL->prepare($commandGetLigant);
	$resultFh->execute() or print "COULD NOT EXECUTE QUERY: " . $DBI::errstr . "\n";;
	$countRow  = 0;
	while(my $row = $resultFh->fetchrow_arrayref) 
	{
		$countRow++;
		my $id       = ${$row}[0];
		my $ligant   = ${$row}[1];
		my $org      = ${$row}[2];
#		print "ID $id LIGANT $ligant ORG $org\n";
		push(@{$ligantSeen{$ligant}[0]}, $id);
		push(@{$ligantSeen{$ligant}[1]}, $org);
	}
	$resultFh->finish();
	print "\t\tQUERY FOR LIGANTS TOOK " . (time-$queryStart) . "s FOR $countRow ROWS AND " . (keys %ligantSeen) . " LIGANTS\n";



	print "\t\tANALYZING SPECIE SPECIFIC LIGANTS\n";
	my $specificityTime        = time;
	my $ligantCount            = 0;
	my $DoubleligantCount      = 0;
	my $DoubleligantEqualCount = 0;
	my $DoubleligantDiffCount  = 0;
	my $SingleligantCount      = 0;
	my @position;
	my @orgs;
	my @result;

	foreach my $ligant (sort keys %ligantSeen)
	{
		@position = @{$ligantSeen{$ligant}[0]};
		@orgs     = @{$ligantSeen{$ligant}[1]};
		if (@position > 1)
		{
			my $notEqual = 0;
			foreach my $org1 (@orgs)
			{
				foreach my $org2 (@orgs)
				{
					if ( ! ($org1 eq $org2)) { $notEqual = 1; }
				}
			};

			if ($notEqual)
			{
				foreach my $pos (@position) { $result[$pos][0] += 16; };
				$DoubleligantDiffCount++;
#				foreach my $pos (@position) { print "$ligant $pos NOT EQUAL " . join(" ", @orgs) ."\n" };
			}
			else
			{
				foreach my $pos (@position) { $result[$pos][0] += 0; };
				$DoubleligantEqualCount++;
#				foreach my $pos (@position) { print "$ligant $pos EQUAL " . join(" ", @orgs) ."\n" };
#				print "\n";
			};
			$DoubleligantCount++;
		}
		else
		{
			$result[$position[0]][0] += 0;
			$SingleligantCount++;
		}
		#print "$ligant > " . join(",", @position) . "\n";
	}
	print "\t\tANALYZING SPECIE SPECIFIC LIGANTS COMPLETED IN " . (time - $specificityTime) . "s\n";
	print "\t\tSINGLE:$SingleligantCount DOUBE: $DoubleligantCount DOUBLE EQUAL: $DoubleligantEqualCount DOUBLE DIFF: $DoubleligantDiffCount\n";

my $analizeSim = 1;
if ($analizeSim)
{
	print "\t\tANALYZING LIGANTS SIMILARITIES\n";	
	my $similarityTime = time;
	my @ligants        = (sort keys %ligantSeen);

	print "\t\t\tGETTING MATRIX\n";
	my $matrixTime = time;
	my $ligantsSim = &similarity::getSimilaritiesMatrix(@ligants);
	print "\t\t\tMATRIX OBTAINED IN " . (time - $matrixTime) . "s\n";

	if ( ! (@ligants && @{$ligantsSim})) { die "COULD NOT RETRIEVE LIGANTS INFORMATION"; };
	for (my $l = 0; $l < @ligants; $l++)
	{
		my @pos = @{$ligantSeen{$ligants[$l]}[0]};

		if (${$ligantsSim}[$l])
		{
			foreach my $pos (@pos)
			{
				$result[$pos][0] += 32;
				$result[$pos][1]  = ${$ligantsSim}[$l];
			#	print "POS $pos LIGANT " . $ligants[$l] . " HAD MORE THAN 50% SIMILARITY " . $ligantsSim[$l] . " TIMES\n";
			}
		}
	}
	print "\t\tANALYZING LIGANTS SIMILARITIES COMPLETED IN " . (time - $similarityTime) . "\n";
}

	my $valid    = 0;
	my $notValid = 0;
	my $kc       = 1;

	print "\t\tUPDATING TABLE WITH " . (@result-1) . " RESULTS\n";
	my $updateTime = time;
	for (my $k = (@result-1); $k > 0 ; $k--) # THE ID FROM SQL STARTS ON 1
	{
		if   (( defined $result[$k] ) && ($result[$k][0] > 0)) 
		{
			$notValid++;
		}
		elsif (( defined $result[$k] ) && ($result[$k][0] == 0)) 
		{
			$valid++; 
		}
		else
		{
			die "VALUE FOR $k IS UNDEF";
		};

		my $result = $result[$k][0];
		my $value  = $result[$k][1];
		if ( ! defined $result ) { $result = 0; };
		if ( ! defined $value  ) { $value  = 0; };
		my $updateExtraFh = $ldbhAL->prepare_cached($commandUpdateExtra);
		   $updateExtraFh->execute($value, $result, $k);
		#if   ($result[$k] > 1) { printf "%20s => %02d\t", ${$rows}[$k][$indLig], $result[$k]; if ( ! ($kc++ % 5)) {print "\n"; }; }
	}

	$ldbhAL->commit();
	$ldbhAL->disconnect();
	print "\t\tUPDATING TABLE COMPLETED IN " . (time - $updateTime) . "s\n";

	print "\tLIGANTS ANALYSIS COMPLETED IN " . (time - $ligantsTime) . "s\n";
	print "\tVALID: $valid\tNOT VALID: $notValid\n";
}



























#######################################
####### SQL COMMOM FUNCTIONS
#######################################
sub sthPrint
{
	my ($fields, $rows);
	($fields, $rows) = @_;
	foreach my $fieldname (@{$fields})
	{
		print "\t$fieldname\n";
	}

	foreach my $row (@{$rows})
	{
		print "\t" . join("  ", @{$row}) . "\n";
	}
}




sub sthExecute
{
	my @lists = @_;

	foreach my $sthE (@lists)
	{
		$sthE->execute();
		my $numOfFields = $sthE->{NUM_OF_FIELDS};
		#my @table       = @{$sthE->{'mysql_table'}};
#		print "TABLE HAS $numOfFields COLUMS\n\n";

		#print "register";
		my @fields;
		my @fieldSize;
		for (my $f = 0; $f < $numOfFields; $f++)
		{
			my $fieldName = $sthE->{NAME}->[$f];
			#print "$fieldName   ";
			push(@fields, $fieldName);
			$fieldSize[$f][0] = length($fieldName);
		}
		#print "\n";

		my $countRow = 1;

		my @values;
		while (my @row = $sthE->fetchrow_array())
		{
			#print "@row\n";
			#print $countRow++ . "\t";
			my @subVal;
			for (my $co = 0; $co < @row; $co++)
			{
				#print $row[$co] . "\t";
				push(@subVal, $row[$co]);
				$fieldSize[$co][0] = length($row[$co]) if (length($row[$co]) > $fieldSize[$co][0]);
				$fieldSize[$co][1] = ($row[$co] =~ /\D/) ? 1 : 0;
			}
			push(@values, \@subVal);
			#print "\n";
		}
		#print "\n"x2;
		warn "PROBLEM RETRIEVING TABLE $database", $sthE->errstr() ,"\n" if $sthE->err();

		if ($sthE->rows == 0)
		{
			print "NO NAMES MATCHED\n";
		}
		else
		{
			my $formatedF;
			my $formatedH;
			for (my $f = 0; $f < @fieldSize; $f++)
			{
				$formatedF .= "%";
				$formatedF .= $fieldSize[$f][1] ? "-" : "";
				$formatedF .= $fieldSize[$f][1] ? ($fieldSize[$f][0]+1) : ($fieldSize[$f][0]);
				$formatedF .= $fieldSize[$f][1] ? "s" : "d ";
				$formatedH .= "%-" . ($fieldSize[$f][0]+1) . "s";
			}

			printf "$formatedH", @fields;
			print "\n";

			for (my $f = 0; $f<@values; $f++)
			{
				printf "$formatedF", @{$values[$f]};
				print "\n";
			}
			print "\n\n";
		}
		$sthE->finish();
	}
}




1;


#373.580 0:01.5382
#SELECT * FROM complete

#0:01.5796
#SELECT * FROM complete WHERE sequenceLig IN (SELECT sequenceLig FROM complete)

#283.887 0:00.3331
#SELECT sequenceLig FROM complete GROUP BY sequenceLig HAVING count(sequenceLig) = 1

#108.959 0:00.7939
#SELECT sequenceM13 FROM complete GROUP BY sequenceM13 HAVING count(sequenceM13) = 1

#278.165 0:00.2771
#SELECT ligant      FROM complete GROUP BY ligant      HAVING count(ligant) = 1

#303.636 0:02.3235
#SELECT * FROM complete GROUP BY sequence HAVING count(sequence) = 1

#crash after 4951 7:18.1314
#SELECT * FROM complete WHERE sequenceLig IN (SELECT sequenceLig FROM complete GROUP BY sequenceLig HAVING count(sequenceLig) = 1)

#102.046 0:02.0911
#SELECT * FROM (SELECT * FROM (SELECT * FROM complete GROUP BY sequenceM13 HAVING count(sequenceM13) = 1) as Tm13 GROUP BY ligant HAVING count(ligant) = 1) as Tligant GROUP BY sequenceLig HAVING count(sequenceLig) = 1

#102.046 0:02.5645
#SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM complete GROUP BY sequenceM13 HAVING count(sequenceM13) = 1) as Tm13 GROUP BY ligant HAVING count(ligant) = 1) as Tligant GROUP BY sequenceLig HAVING count(sequenceLig) = 1) AS Tlig  GROUP BY sequence HAVING count(sequence) = 1


#$listSeq, $listLig, $listM13, $listLiga
#my $avgSize       = int(($maxSize + $minSize)/2);
#my $guess         = int(&log10($listSize));
#my $wordLength    = $guess-(int($guess*.2));
#my $minAppearance = int(&log10($guess)+1.5);
#$wordLength = int(($avgSize * .3)) if (($avgSize * .3) > $wordLength);
#	PHRASES LIST SIZE: 102047 MINSIZE 21 MAXSIZE 30 AVGSIZE 25 WORD LENGTH: 7 MIN APPEARANCE: 2
#	WORD LIST SIZE: 608627
#	WC VALID: 600778 WC NON VALID: 7849 WC TOTAL: 608627
#	RESULT PHRASE VALID: 31408 RESULT PHRASE INVALID: 70639 TOTAL: 102047

#	PHRASES LIST SIZE: 102047 MINSIZE 9 MAXSIZE 14 AVGSIZE 11 WORD LENGTH: 4 MIN APPEARANCE: 2
#	WORD LIST SIZE: 423708
#	WC VALID: 416123 WC NON VALID: 7585 WC TOTAL: 423708
#	RESULT PHRASE VALID: 13037 RESULT PHRASE INVALID: 89010 TOTAL: 102047

#	PHRASES LIST SIZE: 102047 MINSIZE 13 MAXSIZE 17 AVGSIZE 15 WORD LENGTH: 4 MIN APPEARANCE: 2
#	WORD LIST SIZE: 536397
#	WC VALID: 526533 WC NON VALID: 9864 WC TOTAL: 536397
#	RESULT PHRASE VALID: 3245 RESULT PHRASE INVALID: 98802 TOTAL: 102047

#	PHRASES LIST SIZE: 102047 MINSIZE 8 MAXSIZE 8 AVGSIZE 8 WORD LENGTH: 4 MIN APPEARANCE: 2
#	WORD LIST SIZE: 253244
#	WC VALID: 219978 WC NON VALID: 33266 WC TOTAL: 253244
#	RESULT PHRASE VALID: 3294 RESULT PHRASE INVALID: 98753 TOTAL: 102047

