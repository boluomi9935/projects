#!/usr/bin/perl -w
# Saulo Aflitos
# 2009 06 18 19 47
use strict;
use DBI;
use lib "./filters";
use complexity;
use folding;
use similarity;
use dnaCode;
use blast;
use filters::loadconf;
my %pref = &loadconf::loadConf;
#$pref{""}

use threads;
use threads::shared;
use threads 'exit'=>'threads_only';
my $globalTimeStart = time;

#############################
### SETUP
#############################
&loadconf::checkNeeds("doAnalyzeFirstNWBlastGlobal","doAnalyzeFirstNWBlast","doAnalyzeFirstAlmostBlast","doAnalyzeFirstComplexity","doAnalyzeFirstBlat","doAnalyzeFirstQuasiBlast","doTranslateFinalTable","doCreateFinalTable","doAnalyzeExtra","statVerbose","napTime","maxThreads","originalView","originalTable","finalTable","orderBy","primaryKey","batchInsertions","pw","user","host","database","reuse");
my $reuse           = $pref{"reuse"}; 			# table to reuse. undef to create a new table
if (defined $ARGV[0])
{
	$reuse = $ARGV[0];
}
print "REUSE $reuse\n";

	##### EXECUTION
	my $doAnalyzeFirst					= $pref{"doAnalyzeFirst"};	# do first step of analysis
	   my $doAnalyzeFirstQuasiBlast		= $pref{"doAnalyzeFirstQuasiBlast"};		# fragment distribution (rough local alignment - vector search engine google-like) #http://www.perl.com/lpt/a/713
	   my $doAnalyzeFirstBlat			= $pref{"doAnalyzeFirstBlat"};			# RUN EXTERNAL BLAT
	   my $doAnalyzeFirstComplexity		= $pref{"doAnalyzeFirstComplexity"};		# complexity and fold analysis
	   my $doAnalyzeFirstAlmostBlast	= $pref{"doAnalyzeFirstAlmostBlast"};	# almostBlast       (distance + contains/is contained by)
	   my $doAnalyzeFirstNWBlast		= $pref{"doAnalyzeFirstNWBlast"};		# blastNWIterate    (rough NeedlemanWunsch global alignment internal to selected ones)
	   my $doAnalyzeFirstNWBlastGlobal	= $pref{"doAnalyzeFirstNWBlastGlobal"};	# blastNWIterateTwo (rough NeedlemanWunsch global alignment against whole db)

	my $doAnalyzeExtra        = $pref{"doAnalyzeExtra"}; # do second step (TODO)

	my $doCreateFinalTable    = $pref{"doCreateFinalTable"};
	my $doTranslateFinalTable = $pref{"doTranslateFinalTable"};

	##### THREADING
	my $maxThreads      = $pref{"maxThreads"};	# NUMBER OF THREADS
	my $napTime         = $pref{"napTime"};		# SLEEP TIME BETWEEN EACH RETRY TO ADD NEW THREADS
	my $statVerbose     = $pref{"statVerbose"};	# PRINT SUMMARY OF COLUMNS

	##### SQL DB
	my $originalView    = $pref{"originalView"}; 	# original     view  NAME   - origin of data
	my $originalTable   = $pref{"originalTable"}; 	# intermediate table PREFIX - intermediate filter
	my $finalTable      = $pref{"finalTable"}; 		# final        table NAME   - final result. equals to original view but filtered
	my $orderBy         = $pref{"orderBy"}; 		# ORDER BY    statement of final table
	my $primaryKey      = $pref{"primaryKey"};		# PRIMARY KEY statement of final table

	my $database        = $pref{"database"};		# mysql database
	my $host            = $pref{"host"};			# mysql host
	my $user            = $pref{"user"};			# mysql user
	my $pw              = $pref{"pw"};				# mysql pw
	my $batchInsertions = $pref{"batchInsertions"};	# number of batch insertions to the database

	#SQL STATEMENT TO CREATE INTERMEDIARY TABLE
	my $createQuery     =	"SELECT * FROM" .
							" (SELECT * FROM (SELECT * FROM (SELECT * FROM \`$database\`.\`$originalView\`" .
							" GROUP BY sequenceM13 HAVING count(sequenceM13) = 1) AS Tm13" .
							" GROUP BY ligant      HAVING count(ligant)      = 1) AS Tligant" .
							" GROUP BY sequenceLig HAVING count(sequenceLig) = 1) AS Tlig" .
							" GROUP BY sequence    HAVING count(sequence)    = 1";

#SELECT * FROM `probe`.`complete` GROUP BY `sequenceM13`, `ligant`,`sequenceLig`,`sequence` HAVING count(`sequence`)    = 1 AND HAVING count(`sequenceM13`) = 1 AND HAVING count(`ligant`) = 1 AND HAVING count(`sequenceLig`) = 1
#SELECT * FROM `probe`.`complete` GROUP BY `sequenceM13`,`ligant`,`sequenceLig`,`sequence` HAVING count(`sequence`) = 1 AND count(`sequenceM13`) = 1 AND  count(`ligant`) = 1 AND count(`sequenceLig`) = 1

	# NEW COLUMNS FOR INTERMERIARY TABLE
	#																										>[0=AUTOMATIC (toguether w/ complexity analysis); 1=MANUAL RUN (each run reads and saves on sql]
	#	COLUMN NAME			TYPE	SIZE	OPTIONS		VALIDATION TEST										MODE ORDER	FUNCTION				  	BOOLEAN RUN						PROGRAM NAME			|
	#    |--------------------------------------SQL---------------------------------------------------| |-----------------------------------EXECUTION--------------------------------------------------|
	my @newColumns = (
		["Similarity1",		"INT",	"1",	"UNSIGNED",	"Similarity1 IS NULL",								1,	0,		\&sthAnalizeSimilarity1,	$doAnalyzeFirstQuasiBlast,		"quasiblast"],
		["Similarity5",		"INT",	"3",	"UNSIGNED",	"Similarity5 IS NULL",								1,	1,		\&sthAnalizeSimilarity5,	$doAnalyzeFirstBlat,			"external blat"],
		["Similarity2",		"INT",	"3",	"UNSIGNED",	"Similarity2 IS NULL",								1,	3,		\&sthAnalizeSimilarity2,	$doAnalyzeFirstAlmostBlast,		"almostBlast"],	
		#["Similarity3",		"INT",	"5",	"UNSIGNED",	"Similarity3 IS NULL",								1,	4,		\&sthAnalizeSimilarity3,	$doAnalyzeFirstNWBlast,			"blastNWIterate"],
		#["Similarity4",		"INT",	"5",	"UNSIGNED",	"Similarity4 IS NULL",								1,	5,		\&sthAnalizeSimilarity4,	$doAnalyzeFirstNWBlastGlobal,	"blastNWIterateTwo"],
		["Complexity",		"INT",	"1",	"UNSIGNED",	undef,												0,	undef,	undef,						undef,							undef],
		["Folding",			"INT",	"3",	"UNSIGNED",	undef,												0,	undef,	undef,						undef,							undef],
		["FoldingLig",		"INT",	"3",	"UNSIGNED",	undef,												0,	undef,	undef,						undef,							undef],
		["FoldingM13",		"INT",	"3",	"UNSIGNED",	undef,												0,	undef,	undef,						undef,							undef],
		["AnalysisResult",	"INT",	"4",	"UNSIGNED",	"(AnalysisResult = 0 OR AnalysisResult IS NULL)",	0,	2,		\&sthAnalizeFoldComplexity,	$doAnalyzeFirstComplexity,		"complexity"]
	);
	
	#	["Ligant",         "CHAR", "20", "BINARY",   1],
	#	["LigantUnique",   "INT",   "1", "UNSIGNED", 1]



#############################
### INITIALIZATION
#############################
my $addColumn        = "";	# list of columns to add on intermediate table
my $insertInto       = "";	# sql fragment to add values to new columns (automatic ones)
my $countRow         = 0;	# global countrow.		TODO: MAKE LOCAL
my $threadCount      = 0;	# global thread count.	TODO: MAKE LOCAL
   $batchInsertions -= 1;	# decrease by one so it's 0 based

my %ligantSeen;		# list of ligants already seen. TODO: MAKE LOCAL
my %oldColumnIndex;	# original columns columns index
my %newColumnIndex;	# new      columns columns index
my @execution;		# execution order array with names [#] = $name



### CREATING SQL STATEMENTS BASED ON NEW COLUMNS
foreach my $info (@newColumns)
{
	# SQL
	my $name        = ${$info}[0];
	my $type        = ${$info}[1];
	my $size        = ${$info}[2];
	my $extra       = ${$info}[3];
	my $validation  = ${$info}[4];
	# EXECUTION
	my $secondRound = ${$info}[5];
	my $order       = ${$info}[6];
	my $function    = ${$info}[7];
	my $run         = ${$info}[8];
	my $displayName = ${$info}[9];

	$addColumn     .= ", ADD COLUMN $name $type";
	$addColumn     .= " ($size)" if $size;
	$addColumn     .= " $extra"  if $extra;

	$newColumnIndex{$name} = undef;

	if ( ! $secondRound )
	{
		$insertInto .=  ", " if ($insertInto ne "");
		$insertInto .=  "$name = ?";
	}

	
	if (defined $order)
	{
		$execution[$order]{"name"}        = $name;
		$execution[$order]{"validation"}  = $validation;
		$execution[$order]{"function"}    = $function;
		$execution[$order]{"update"}      = "$name = ? WHERE Id = ?";
		$execution[$order]{"run"}         = $run;
		$execution[$order]{"displayName"} = $displayName;
	}

	if (( ! $secondRound ) && (defined $order))
	{
		$execution[$order]{"update"}    = $insertInto . " WHERE Id = ?";
	}

}


if ($reuse)
{
	$originalTable .= $reuse;
}
else
{
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	my $timeStamp      = sprintf("%04d%02d%02d%02d%02d", (1900+$year), ($mon+1), $mday, $hour, $min);
	$originalTable .= $timeStamp;
}






#############################
### SQL STATEMENTS
#############################
my $FROM                     = "\`$database\`.\`$originalTable\`";
my $commandCreateTable       = "CREATE TABLE $FROM ENGINE InnoDB $createQuery";				# SQL STATEMENT TO CREATE INTERMEDIATE TABLE
my $commandAddColumn         =	"ALTER  TABLE $FROM"                                   .	# SQL STATEMENT TO ADD NEW COLUMNS
								" ADD COLUMN Id INT UNSIGNED NOT NULL AUTO_INCREMENT," .	# AND ID PRIMARY KEY TO INTERMEDIATE TABLE
								" ADD PRIMARY KEY (Id)$addColumn"; 

my $selectOriginalTable      = "SELECT * FROM $FROM";	# SQL STATEMENT TO SELECT ALL RESULTS FROM INTERMEDIATE TABLE. GLOBAL
my $updateOrignalTable       = "UPDATE $FROM";			# SQL STATEMENT TO UPDATE INTERMEDIATE TABLE

my $commandGetAllResults     = "$selectOriginalTable";	# SQL STATEMENT TO GET ALL RESULTS
														# FROM INTERMEDIATA TABLE. POSSIBLE TO CHANGE AND FILTER
my $createQueryFinalWhere;

# GENERATING SEQUENCE SPECIFIC SQL STATEMENTS
my %sql;
for (my $e = 0; $e < @execution; $e++)
{
	my $name = $execution[$e]->{"name"};
	$sql{$name}->{"name"}        = $name; 							# COLUMN NAME
	$sql{$name}->{"run"}         = $execution[$e]->{"run"};			# BOOLEAN RUN OR NOT
	$sql{$name}->{"displayName"} = $execution[$e]->{"displayName"}; # DIAPLAY NAME
	$sql{$name}->{"function"}    = $execution[$e]->{"function"};	# REF TO FUNCTION TO BE CALLED
	$sql{$name}->{"update"}      = $updateOrignalTable . " SET " . $execution[$e]->{"update"}; # UPDATE SQL STATEMENT

	$sql{$name}->{"input"}       = $selectOriginalTable . " WHERE "; # INPUT SQL STATEMENT

	# GENERATING VALIDATION SQL STATEMENTS
	if ($e == 0)
	{
		$sql{$name}->{"input"}  = $commandGetAllResults;
		$sql{$name}->{"result"} = $sql{$name}->{"input"} . " WHERE " . $execution[$e]->{"validation"};
	}
	else
	{
		for (my $f = 0; $f < $e; $f++)
		{
			$sql{$name}->{"input"} .= $execution[$f]->{"validation"};
			if ($f <= ($e-2)) { $sql{$name}->{"input"} .= " AND " };
		}

		$sql{$name}->{"result"} = $sql{$name}->{"input"} . " AND " . $execution[$e]->{"validation"};
	}

	# SQL STATEMENT TO GET THE FINAL VALID RESULTS (CONCATENATION OF ALL VALIDATIONS)
	$createQueryFinalWhere .= " AND " if (defined $createQueryFinalWhere);
	$createQueryFinalWhere .= $execution[$e]->{"validation"};
}


my $commandUpdateLigants    = "$updateOrignalTable SET ligant = ? WHERE Id = ?";
# TO DELETE






if ( ! $reuse )
{
	&sthInsertCreate($commandCreateTable, $commandAddColumn);
	# create table out of result view
}
else
{
	print "INSERT :: REUSING $reuse TABLE\n";
}

&sthAnalizeStat($commandGetAllResults . " LIMIT 1");	# get result table





my @oldColumns = (sort keys %oldColumnIndex);
my $oldColumnsStr = join(",", @oldColumns);

# GENERATE SQL STATEMENT TO CREATE FINAL TABLE WITHOUT NEW COLUMNS
my $FROMFINAL                     = "\`$database\`.\`$finalTable\`";
my $FROMFINALCOPY                 = "\`$database\`.\`$finalTable\_translated\`";

my $commandDropFinalTable         = "DROP TABLE IF EXISTS $FROMFINAL";
my $commandDropFinalTableCopy     = "DROP TABLE IF EXISTS $FROMFINALCOPY";

my $commandCreateFinalTable       = "CREATE TABLE "          . $FROMFINAL;
   $commandCreateFinalTable      .= " (PRIMARY KEY ("        . $primaryKey    . "))"	if ( defined $primaryKey );				# ADD PRIMARY KEY
   $commandCreateFinalTable      .= " ENGINE InnoDB SELECT " . ($oldColumnsStr || "*");						 					# SQL STATEMENT TO GENERATE FINAL TABLE CONTAININ ONLY THE ORIGINAL COLUMNS AND NOT THE ANALYSIS STEPS
   $commandCreateFinalTable      .= " FROM "                 . $FROM;															# FROM INTERMEDIARY TABLE
   $commandCreateFinalTable      .= " WHERE "                . $createQueryFinalWhere	if ( defined $createQueryFinalWhere );	# ADD WHERE STATEMENT CONTAINING ALL VALIDATIONS
   $commandCreateFinalTable      .= " ORDER BY "             . $orderBy 				if ( defined $orderBy );				# ADD ORDER BY CLAUSULE

my $star                          = "ligant, sequence, sequenceLig, sequenceM13";

my $commandCopyFinalTable         = "CREATE TABLE $FROMFINALCOPY SELECT $star FROM $FROMFINAL";
my $commandFinalTableIndex        =	"ALTER  TABLE $FROMFINALCOPY ADD PRIMARY KEY (Id)"; 

$star                            .= "Id, ";
my $commandGetAllFinalResults     = "SELECT $star FROM $FROMFINAL";
my $commandGetAllFinalCopyResults = "SELECT $star FROM $FROMFINALCOPY";
#my $commandUpdateFinalTableCopy   = "UPDATE $FROMFINALCOPY SET ligant = ?, sequence = ?, sequenceLig = ?, sequenceM13 = ? WHERE Id = ?";
my $commandUpdateFinalTableCopy   = "UPDATE $FROMFINALCOPY SET ligant = \'<0>\', sequence = \'<1>\', sequenceLig = \'<2>\', sequenceM13 = \'<3>\' WHERE Id = \'<4>\'";

my $commandCheckFinalTable        = "SELECT $star FROM $FROMFINAL";

#CREATE TABLE test (PRIMARY KEY (idOrganism)) ENGINE InnoDB (SELECT idOrganism, count(*) FROM complete GROUP BY idOrganism)
#my $commandAddPrimaryKey     = "ALTER  TABLE         $FROMFINAL  ADD PRIMARY KEY (Id)"; 

#print "_"x2, "COMMAND DROP FINAL TABLE   :\n\t", $commandDropFinalTable,   "\n";
#print "_"x2, "COMMAND CREATE FINAL TABLE :\n\t", $commandCreateFinalTable, "\n";
#print "COMMAND ADD PRIMARY KEY    :\n\t", $commandAddPrimaryKey,    "\n";













# TO CHECK SQL STATEMENT
# TO DELETE
if (0)
{
	foreach my $key (sort keys %sql)
	{
		print "KEY : ",$key,"\n";
		foreach my $sub (keys %{$sql{$key}})
		{
			print "\t\t", $sub,"\t",$sql{$key}{$sub},"\n";
		}
	}

	die;
}



#############################
### PROGRAM
#############################



if ($doAnalyzeFirst)
{
	&sthAnalyzeFirst();	# analyze anything that can be done row by row.
						# update the table at the end automatically
						# threaded
}

print "SELECTION DONE. CONGRATS\n";
print "COMPLETION IN : ", (time-$globalTimeStart), "s\n";












#############################
### SUBS
#############################

sub sthTranslateFinalTable() #TODO
{
	my $commandGet    = $_[0];
	my $commandUpdate = $_[1];
	my @colums        = @_[ 2 .. (@_-1)];

	print "_"x2, "TRANSLATION :: DATABASE TRANSLATION\n";
	print "_"x4, "TRANSLATION :: RETRIEVING RESULT\n";
	my $dbh1 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
		 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $sth1 = $dbh1->prepare($commandGet);
	$sth1->execute();

	my $rows = $sth1->rows;

	print "_"x6, "TRANSLATION :: ", $rows, " RESULTS RETRIEVED SUCCESSIFULLY\n";



	   $countRow  = 0;
	my $startTime   = time;

	my @translated;

	my $oldColumnIndex = $oldColumnIndex{"Id"};

	while(my $row = $sth1->fetchrow_arrayref) 
	{
		$countRow++;

		print "_"x4, "TRANSLATION :: ACQUIRING ROW # $countRow\n" if ( ! ($countRow % (int ($rows / 20))));
		my @row     = @{$row};
		my $rowNum  = $row[$oldColumnIndex];

		for (my $a = 0; $a < @colums; $a++)
		{
			push(@{$translated[$rowNum]}, &dnaCode::digit2dna($row[$colums[$a]]));
			#print "ROW $rowNum COLUMN $colums[$a] SEQORIG $row[$colums[$a]] SEQTRAN $translated[$rowNum][$colums[$a]]\n";
		}
		push(@{$translated[$rowNum]}, $rowNum);
	}
	$sth1->finish();
	$dbh1->commit();

	print "_"x4, "TRANSLATION :: DATA GATHERED TO TRANSLATION: ", (int((time - $startTime)+.5)), "s\n";

	print "_"x4, "TRANSLATION :: GENERATING BATCH INSERTION SCRIPT\n";
	my $queryStart   = time;
	my $countResults = 0;
	my @values;
	my $valuesP 	 = 0;
	my $valuesPzinho = 0;

	open UPDATE, ">update.sql" or die "COULD NOT OPEN UPDATE.SQL";
	for (my $r = 0; $r < @translated; $r++)
	{
		if (defined $translated[$r])
		{
			#if (defined $values[$valuesP]) { $values[$valuesP] .= ", "; };
			#$values[$valuesP] .= "(\'";
			#$values[$valuesP] .= join("\',\'", @{$translated[$r]});
			#$values[$valuesP] .= "\')";
			my $tmpUpdate = $commandUpdate;

			while ($tmpUpdate =~ m/\<(\d*)\>/g)
			{
				my $pos = $1;

#				if (defined $translated[$r][$pos])
#				{
					$tmpUpdate =~ s/\<$pos\>/$translated[$r][$pos]/;
#				}
			}

			print UPDATE $tmpUpdate, ";\n";
#			print "$tmpUpdate\n";
			#$values[$valuesP++] .= $tmpUpdate . ";\n";
			#if (($valuesPzinho++ >= $batchInsertions) || ($valuesPzinho >= ($rows/500))){ $valuesP++; $valuesPzinho = 0; };
		}
	}

	close UPDATE;
	print "_"x4, "TRANSLATION :: BATCH INSERTION SCRIPT CREATED : $valuesP ROUNDS OF INSERTIONS NEEDED\n";
	print "_"x4, "TRANSLATION :: INSERTING DATA\n";

	my $mysqlCmd = $pref{"mysqlCmd"};
	print `time sudo $mysqlCmd < update.sql`;

	#for (my $r = 0; $r < @values; $r++)
	#{
	#	print "_"x4, "TRANSLATION :: INSERTING ROW # $countResults\n" if ( ! ($countRow % (int (@values / 20))));
	#	print $r, " ", $values[$r] , "\n";
#	#	my $updateFirstFh = $dbh1->prepare_cached($values[$r]);
	#	my $updateFirstFh = $dbh1->prepare($values[$r]);
	#	   $updateFirstFh->execute();
	#	   $updateFirstFh->finish();
	#	$countResults++;
	#}
	#$dbh1->commit();
	#$dbh1->disconnect();

	print "_"x4, "TRANSLATION :: UPDATE QUERY TIME : " , (time-$queryStart) , "s FOR ", $countResults," QUERIES\n";
	print "_"x4, "TRANSLATION :: TOTAL TIME : ", (int((time - $startTime)+.5)), "s\n";
	print "_"x2, "TRANSLATION :: TRANSLATION COMPLETED\n\n\n";

	return undef;
}







#######################################
####### CORE FUNCTIONS
#######################################
sub sthInsertCreate
{
	my $insertTime = time;
	my @commands = @_;

	print "INSERT :: RUNNING COMMANDS\n";
	my $dbhI = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
		 or die "INSERT :: COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

	foreach my $command (@commands)
	{
		print "\tINSERT :: RUNNING COMMAND : $command\n";
		$dbhI->do($command);
	}

	print "INSERT :: COMPLETED IN    : ", (time - $insertTime), "s\n";
	$dbhI->commit();
	$dbhI->disconnect();
}


sub sthAnalyzeFirst
{
	print "ANALIZE FIRST :: STARTING FIRST STEP OF ANALYSIS\n";

	# RUNS BY EXECUTION ORDER
	for (my $e = 0; $e < @execution; $e++)
	{
		my $name = $execution[$e]->{"name"};
		if ($sql{$name}->{"run"})
		{
			print "\tDISPLAY NAME  : ", $sql{$name}->{"displayName"} , "\n";
			print "\tFILLING COLUMN: ", $name                        , "\n";
			print "\tINPUT         : ", $sql{$name}->{"input"}       , "\n";
			print "\tUPDATE        : ", $sql{$name}->{"update"}      , "\n\n";

			# EXECUTES THE REQUESTED FUNCTION SENDING
			$sql{$name}->{"function"}->(
				$name, $sql{$name}->{"displayName"},	# THE DISPLAY NAME
				$sql{$name}->{"input"},					# THE INPUT       SQL STATEMENT
				$sql{$name}->{"update"},				# THE UPDATE      SQL STATEMENT
				$commandGetAllResults);					# THE ALL RESULTS SQL STATEMENT
		}
	}

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
	$sthS->execute() or die "COULD NOT EXECUTE $command : $! : $DBI::errstr";
	print "_"x4, "STAT :: RESULT RETRIEVED SUCCESSIFULLY\n";

	# RETRIEVE THE TOTAL NUMBER OF FIELDS
	my $numOfFields = $sthS->{NUM_OF_FIELDS};
	my $numOfRows   = $sthS->rows;

	print "_"x6, "STAT :: RESULT : ", $numOfRows,   " ROWS RETRIEVED\n";
	print "_"x6, "STAT :: RESULT : ", $numOfFields, " COLUMNS FOUND\n";

	# GETS EACH COLUMN INDEX SO ONE CAN RETIEVE
	# ARRAY INSTEAD OF HASH
	my @fields;
	for (my $f = 0; $f < $numOfFields; $f++)
	{
		my $fieldName = $sthS->{NAME}->[$f];

		if (exists $newColumnIndex{$fieldName})
		{
			$newColumnIndex{$fieldName} = $f
		}
		else
		{
			$oldColumnIndex{$fieldName} = $f;
		}
	}


	my $maxLen = 9;

	foreach my $key (sort keys %oldColumnIndex)
	{
		if ( $oldColumnIndex{$key} eq "" )
		{
			die "COULD NOT OBTAIN COLUM INDEX FOR $key";
		}
		$maxLen = length($key) if (length($key) > $maxLen);
	}

	foreach my $key (sort keys %newColumnIndex)
	{
		if ( ! defined $newColumnIndex{$key} )
		{
			die "COULD NOT OBTAIN COLUM INDEX FOR $key";
		}
		$maxLen = length($key) if (length($key) > $maxLen);
	}

	if ($statVerbose)
	{
		print "_"x4, "STAT :: TOTAL COLUMNS : ", ((scalar keys %oldColumnIndex) + (scalar keys %newColumnIndex)) , "\n";
		print "\tOLD\n";

		foreach my $col (sort keys %oldColumnIndex)
		{
			printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", uc($col), $oldColumnIndex{$col};

			if ( ! (defined $oldColumnIndex{$col})) { die "NEW COLUMN $col NOT FOUND\n"; };
		}

		printf "\tNEW\n";

		foreach my $col (sort keys %newColumnIndex)
		{
			printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", uc($col), $newColumnIndex{$col};

			if ( ! (defined $newColumnIndex{$col})) { die "NEW COLUMN $col NOT FOUND\n"; };
		}
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

	##########
	## SIMILARITY 1 - QUASIBLAST
	##########
	sub sthAnalizeSimilarity1
	{
		my $name          = $_[0];
		my $displayName   = $_[1];
		my $commandGet    = $_[2];
		my $commandUpdate = $_[3];
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
			my $org     = $row[$oldColumnIndex{"idOrganism"}];
			#my $seqLig = $row[$oldColumnIndex{"sequenceLig"}];
			#my $seqM13 = $row[$oldColumnIndex{"sequenceM13"}];
			my $seqSeq  = $row[$oldColumnIndex{"startLig"}];
			my $seqLiga = $row[$oldColumnIndex{"ligant"}];
			my $rowNum  = $row[$oldColumnIndex{"Id"}];

			#$listLig[$rowNum]  = $seqLig;
			#$listM13[$rowNum]  = $seqM13;
			$listSeq[$rowNum]  = $seqSeq;
			$listLiga[$rowNum] = $seqLiga;
		}
		$sth1->finish();
		$dbh1->commit();
		$dbh1->disconnect();

		print "_"x4, "SIMILARITY 1 :: DATA GATHERED TO SIMILARITY ANALYSIS 1: ", (int((time - $startTime)+.5)), "s\n";
		#####################
		#&analizeSimilarity1($commandUpdate, \@listLig, \@listM13, \@listSeq, \@listLiga);
		&analizeSimilarity1($commandUpdate, \@listSeq, \@listLiga);
		#####################
		print "_"x2, "SIMILARITY 1 :: SIMILARITY ANALYSIS 1 COMPLETED\n\n\n";
	}


	sub analizeSimilarity1
	{
		my $commandUpdate = $_[0];

		my $Gresult  = [];

		my $startTime = time;

		#####################
		for my $input (@_[1 .. (scalar @_ - 1)])
		{
			$Gresult = &similarity::quasiBlast($Gresult, $input);
		}
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



	##########
	## SIMILARITY 2 - ALMOSTBLAST + NWBLAST
	##########
	sub sthAnalizeSimilarity2
	{
		my $name          = $_[0];
		my $displayName   = $_[1];
		my $commandGet    = $_[2];
		my $commandUpdate = $_[3];
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
#			my $org     = $row[$oldColumnIndex{"idOrganism"}];
#			my $seqLig  = $row[$oldColumnIndex{"sequenceLig"}];
#			my $seqM13  = $row[$oldColumnIndex{"sequenceM13"}];
			my $seqSeq  = $row[$oldColumnIndex{"sequence"}];
			my $seqLiga = $row[$oldColumnIndex{"ligant"}];
			my $rowNum  = $row[$oldColumnIndex{"Id"}];

			#$listLig[$rowNum]  = $seqLig;
			#$listM13[$rowNum]  = $seqM13;
			$listSeq[$rowNum]  = $seqSeq;
			$listLiga[$rowNum] = $seqLiga;
		}
		$sth2->finish();
		$dbh2->commit();
		$dbh2->disconnect();

		print "_"x4, "SIMILARITY 2 :: DATA GATHERED TO SIMILARITY ANALYSIS 2: ", (int((time - $startTime)+.5)), "s\n";

#		&analizeSimilarity2($commandUpdate, \@listSeq, \@listLiga);

		my $parts       = $maxThreads;
		my $threadCount = 0;
		foreach my $array (\@listSeq, \@listLiga)
		{
			my @part;
			my $arraySize = (scalar @{$array});
			my $fraction  = int($arraySize/$parts)+1;

			for (my $p = 0; $p < $parts; $p++)
			{
				my $start = $p     * $fraction;
				my $end   = $start + $fraction -1;
				while ($end >= $arraySize) {$end--};
#				print "START: $start END: $end FRACTION: $fraction PARTS: $parts TOTAL: ",$arraySize, "\n";
				$part[$p] = @{$array}[$start .. $end];
			}

			for (my $r = 0; $r < $parts; $r++)
			{
				while (threads->list(threads::running) > ($maxThreads-1))
				{
					sleep($napTime); 
				}

				foreach my $thr (threads->list(threads::joinable))
				{
					$thr->join();
				}

				$threadCount++;
				print "_"x6, "SIMILARITY 2 :: STARTING SIMILARITY ANALYSIS 2 : THREAD ", $threadCount, "\n";
				#####################
				threads->new(\&analizeSimilarity2, ($commandUpdate, $array));
				#####################
			}
		}


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


		print "_"x2, "SIMILARITY 2 :: SIMILARITY ANALYSIS 2 COMPLETED\n\n\n";
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



	##########
	## SIMILARITY 3 - NWBLAST
	##########
	sub sthAnalizeSimilarity3
	{
		my $name          = $_[0];
		my $displayName   = $_[1];
		my $commandGet    = $_[2];
		my $commandUpdate = $_[3];
		print "_"x2, "SIMILARITY 3 :: STARTING SIMILARITY ANALYSIS 2\n";
		print "_"x4, "SIMILARITY 3 :: RETRIEVING RESULT\n";
		my $dbh3 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
		my $sth3 = $dbh3->prepare($commandGet);
		$sth3->execute();
		print "_"x6, "SIMILARITY 3 :: ", $sth3->rows, " RESULT RETRIEVED SUCCESSIFULLY\n";

		   $countRow  = 0;
		my $startTime   = time;

		my @listLig;
		my @listM13;
		my @listSeq;
		my @listLiga;

		while(my $row = $sth3->fetchrow_arrayref) 
		{
			$countRow++;
			print "_"x4, "SIMILARITY 3 :: ACQUIRING ROW # $countRow\n" if ( ! ($countRow % 25_000));
			my @row     = @{$row};

			#my $org     = $row[$oldColumnIndex{"idOrganism"}];
			#my $seqLig  = $row[$oldColumnIndex{"sequenceLig"}];
			#my $seqM13  = $row[$oldColumnIndex{"sequenceM13"}];
			my $seqSeq  = $row[$oldColumnIndex{"sequence"}];
			my $seqLiga = $row[$oldColumnIndex{"ligant"}];
			my $rowNum  = $row[$oldColumnIndex{"Id"}];

			#$listLig[$rowNum]  = $seqLig;
			#$listM13[$rowNum]  = $seqM13;
			$listSeq[$rowNum]  = $seqSeq;
			$listLiga[$rowNum] = $seqLiga;
		}
		$sth3->finish();
		$dbh3->commit();
		$dbh3->disconnect();

		print "_"x4, "SIMILARITY 3 :: DATA GATHERED TO SIMILARITY ANALYSIS 3: ", (int((time - $startTime)+.5)), "s\n";
		#####################
		#&analizeSimilarity3($commandUpdate, \@listSeq, \@listLiga);
		#####################


		my $threadCount = 0;
		foreach my $array (\@listSeq, \@listLiga)
		{
			while (threads->list(threads::running) > ($maxThreads-1))
			{
				sleep($napTime); 
			}

			foreach my $thr (threads->list(threads::joinable))
			{
				$thr->join();
			}

			$threadCount++;
			print "_"x6, "SIMILARITY 3 :: STARTING SIMILARITY ANALYSIS 3 : THREAD ", $threadCount, "\n";
			#####################
			threads->new(\&analizeSimilarity3, ($commandUpdate, $array));
			#####################
		}


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


		print "_"x2, "SIMILARITY 3 :: SIMILARITY ANALYSIS 3 COMPLETED\n\n\n";
	}

	sub analizeSimilarity3
	{
		my $commandUpdate = $_[0];

		my $Gresult  = [];

		my $startTime = time;

		#####################
		$Gresult = &blast::blastNWIterate($Gresult, @_[1 .. (scalar @_ - 1)]);
		#####################
		my $h = 0;
		for (my $g = 0; $g <@{$Gresult}; $g++)
		{
			if (defined $Gresult->[$g]) { $h++ }
		}
		print "_"x4, "SIMILARITY 3 :: AFTER BLASTNW: $h INVALIDS\n\n";


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




	##########
	## SIMILARITY 4 - GLOBAL NWBLAST
	##########
	sub sthAnalizeSimilarity4
	{
		my $name            = $_[0];
		my $displayName     = $_[1];
		my $commandGetValid = $_[2];
		my $commandUpdate   = $_[3];
		my $commandGetAll   = $_[4];

		print "_"x2, "SIMILARITY 4 :: STARTING SIMILARITY ANALYSIS 4\n";
		print "_"x4, "SIMILARITY 4 :: RETRIEVING RESULT\n";

		my $dbh4 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

		my $sth4V = $dbh4->prepare($commandGetValid);
		$sth4V->execute();
		my $rowsV = $sth4V->rows;
		print "_"x6, "SIMILARITY 4 :: ",$rowsV, " RESULT RETRIEVED SUCCESSIFULLY\n";

		my $sth4A = $dbh4->prepare($commandGetAll);
		$sth4A->execute();
		my $rowsA = $sth4A->rows;
		print "_"x6, "SIMILARITY 4 :: ",$rowsA, " RESULTS RETRIEVED SUCCESSIFULLY\n";

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
		while(my $row = $sth4V->fetchrow_arrayref) 
		{
			$countRow++;
			print "_"x4, "SIMILARITY 4 :: ACQUIRING VALID ROW # $countRow\n" if ( ! ($countRow % (int($rowsV / 5))));
			my @row     = @{$row};

			my $org     = $row[$oldColumnIndex{"idOrganism"}];
			my $seqLig  = $row[$oldColumnIndex{"sequenceLig"}];
			my $seqM13  = $row[$oldColumnIndex{"sequenceM13"}];
			my $seqSeq  = $row[$oldColumnIndex{"sequence"}];
			my $seqLiga = $row[$oldColumnIndex{"ligant"}];
			my $rowNum  = $row[$oldColumnIndex{"Id"}];

			#$listLigV[$rowNum]  = $seqLig;
			#$listM13V[$rowNum]  = $seqM13;
			$listSeqV[$rowNum]  = $seqSeq;
			$listLigaV[$rowNum] = $seqLiga;
		}
		$sth4V->finish();

		$countRow  = 0;
		while(my $row = $sth4A->fetchrow_arrayref) 
		{
			$countRow++;
			print "_"x4, "SIMILARITY 4 :: ACQUIRING ALL ROW # $countRow\n" if ( ! ($countRow % (int($rowsA / 5))));
			my @row     = @{$row};

			my $org     = $row[$oldColumnIndex{"idOrganism"}];
			my $seqLig  = $row[$oldColumnIndex{"sequenceLig"}];
			my $seqM13  = $row[$oldColumnIndex{"sequenceM13"}];
			my $seqSeq  = $row[$oldColumnIndex{"sequence"}];
			my $seqLiga = $row[$oldColumnIndex{"ligant"}];
			my $rowNum  = $row[$oldColumnIndex{"Id"}];

			#$listLigA[$rowNum]  = $seqLig;
			#$listM13A[$rowNum]  = $seqM13;
			$listSeqA[$rowNum]  = $seqSeq;
			$listLigaA[$rowNum] = $seqLiga;
		}
		$sth4A->finish();

		$dbh4->commit();
		$dbh4->disconnect();


		print "_"x4, "SIMILARITY 4 :: DATA GATHERED TO SIMILARITY ANALYSIS 4: ", (int((time - $startTime)+.5)), "s\n";
		#####################
		&analizeSimilarity4($commandUpdate, \@listSeqV, \@listSeqA, \@listLigaV, \@listLigaA);
		#####################
		print "_"x2, "SIMILARITY 4 :: SIMILARITY ANALYSIS 4 COMPLETED\n\n\n";
	}

	sub analizeSimilarity4
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
		print "SIMILARITY 4 :: AFTER BLASTNWTWO : $h INVALIDS\n";


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

		print "_"x4, "SIMILARITY 4 :: VALID: ", $resultValid," INVALID: ", $resultInValid,"\n";

		# 1=not ok null=ok


		my $queryStart = time;
		my $ldbh4 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
				or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
		my $countResults = 0;
		for (my $r = 0; $r < @{$Gresult}; $r++)
		{
			if (defined $Gresult->[$r])
			{
				#print join("\t", @{$result}) . "\n";
				my $updateFirstFh = $ldbh4->prepare_cached($commandUpdate);
				   $updateFirstFh->execute($Gresult->[$r], $r);
				   $updateFirstFh->finish();
				$countResults++;
			}
		}
		$ldbh4->commit();
		$ldbh4->disconnect();

		print "_"x4, "SIMILARITY 4 :: UPDATE QUERY TIME : " , (time-$queryStart) , "s FOR ",$countResults," QUERIES\n";
		print "_"x4, "SIMILARITY 4 :: TOTAL TIME : ", (int((time - $startTime)+.5)), "s\n";
		return undef;
	}




	##########
	## SIMILARITY 5 - EXTERNAL BLAST
	##########
	sub sthAnalizeSimilarity5
	{
		my $name            = $_[0];
		my $displayName     = $_[1];
		my $commandGetValid = $_[2];
		my $commandUpdate   = $_[3];
		my $commandGetAll   = $_[4];

		print "_"x2, "SIMILARITY 5 :: STARTING SIMILARITY ANALYSIS 5\n";
		print "_"x4, "SIMILARITY 5 :: RETRIEVING RESULT\n";

		my $dbh5 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

		my $sth5V = $dbh5->prepare($commandGetValid);
		$sth5V->execute();
		my $rowsV = $sth5V->rows;
		print "_"x6, "SIMILARITY 5 :: ",$rowsV, " VALID RESULTS RETRIEVED SUCCESSIFULLY\n";

		my $sth5A = $dbh5->prepare($commandGetAll);
		$sth5A->execute();
		my $rowsA = $sth5A->rows;
		print "_"x6, "SIMILARITY 5 :: ",$rowsA, " ALL RESULTS RETRIEVED SUCCESSIFULLY\n";

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
		while(my $row = $sth5V->fetchrow_arrayref) 
		{
			$countRow++;
			print "_"x4, "SIMILARITY 5 :: ACQUIRING VALID ROW # $countRow\n" if ( ! ($countRow % (int($rowsV / 5))));
			my @row     = @{$row};

			my $seqSeq  = $row[$oldColumnIndex{"sequence"}];
			my $seqLiga = $row[$oldColumnIndex{"ligant"}];
			my $rowNum  = $row[$oldColumnIndex{"Id"}];

			#$listLigV[$rowNum]  = $seqLig;
			#$listM13V[$rowNum]  = $seqM13;
			$listSeqV[$rowNum]  = $seqSeq;
			$listLigaV[$rowNum] = $seqLiga;
		}
		$sth5V->finish();

		$countRow  = 0;
		while(my $row = $sth5A->fetchrow_arrayref) 
		{
			$countRow++;
			print "_"x4, "SIMILARITY 5 :: ACQUIRING ALL ROW # $countRow\n" if ( ! ($countRow % (int($rowsA / 5))));
			my @row     = @{$row};

			#my $org     = $row[$oldColumnIndex{"idOrganism"}];
			my $seqSeq  = $row[$oldColumnIndex{"sequence"}];
			my $seqLiga = $row[$oldColumnIndex{"ligant"}];
			my $rowNum  = $row[$oldColumnIndex{"Id"}];

			#$listLigA[$rowNum]  = $seqLig;
			#$listM13A[$rowNum]  = $seqM13;
			$listSeqA[$rowNum]  = $seqSeq;
			$listLigaA[$rowNum] = $seqLiga;
		}
		$sth5A->finish();

		$dbh5->commit();
		$dbh5->disconnect();


		print "_"x4, "SIMILARITY 5 :: DATA GATHERED TO SIMILARITY ANALYSIS 5: ", (int((time - $startTime)+.5)), "s\n";
		#####################
		&analizeSimilarity5($commandUpdate, \@listSeqV, \@listSeqA, \@listLigaV, \@listLigaA);
		#####################
		print "_"x2, "SIMILARITY 5 :: SIMILARITY ANALYSIS 5 COMPLETED\n\n\n";
	}

	sub analizeSimilarity5
	{
		my $commandUpdate = $_[0];

		my $Gresult  = [];

		my $startTime = time;

		for (my $r = 1; $r < @_; $r +=2)
		{
			my $arrayV  = $_[$r];

			my $fileCount = 1;

			my $blatFolder = "blat";
			my $queryFile  = "$blatFolder/$r\_query.fa";
			my $dbFile     = "$blatFolder/$r\_db.fa";
			my $resultFile = "$blatFolder/$r\_result";
#			if(1){
			open  QUERY, ">$queryFile" 
                or die "COULD NOT OPEN $queryFile: $!";
			my $maxSize = 0;
			my $minSize = 300;
			for (my $a = 0; $a < @$arrayV; $a++)
			{
				next if ( ! defined $arrayV->[$a]);
				my $seq   = &dnaCode::digit2dna($arrayV->[$a]);

				die "SEQUENCE OF LENGTH 0 FOUND " if (length($seq) == 0);
				$maxSize  = length($seq) if (length($seq) > $maxSize);
				$minSize  = length($seq) if (length($seq) < $minSize);

				my $query = ">". $a . "|" . $a . "_" . $a . "\n" . $seq . "\n\n";

				print QUERY $query;

				$fileCount++;
			}
			close QUERY;

			if ( ! $fileCount ) { die "NO SEQUENCES TO BLAT"; };

			open  DB, ">$dbFile" or die "COULD NOT OPEN $dbFile: $!";
			my $arrayA  = $_[$r+1];
			for (my $a = 0; $a < @$arrayA; $a++)
			{
				next if ( ! defined $arrayA->[$a]);
				my $seq = &dnaCode::digit2dna($arrayA->[$a]);
				while (length($seq) < $maxSize) { $seq .= "N" };
				print DB ">", $a , "|" , $a , "_" , $a , "\n" , $seq , "\n\n";
			}
			close DB;
#			} #end if 0


			print "_"x6, "SIMILARITY 5 :: RUNNING BLAT\n";
			#blat/filterpsl.sh blat blat/3_db.fa blat/3_query.fa blat/3_result 20
			################
			my $blatCMD = "$blatFolder/filterpsl.sh $blatFolder $dbFile $queryFile $resultFile $minSize 50 70";
			print "_"x6, $blatCMD, "\n";
			print `$blatCMD`;
			################
			print "_"x6, "SIMILARITY 5 :: BLAT RUNNED\n";

			print "_"x6, "SIMILARITY 5 :: LOADING BLAT RESULT\n";

			my $resultFileFinal = `ls $resultFile\_*\_filtered_threshold_neg.lst 2>/dev/null`;
			chomp $resultFileFinal;

			if ( -f $resultFileFinal )
			{
				open RESULT, "<$resultFileFinal" or die "COULD NOT OPEN RESULT FILE $resultFileFinal: $!";
				while (my $line = <RESULT>)
				{
					chomp $line;
					$Gresult->[$line] = 1;
				}
				close RESULT;
			}
			else
			{
				die "COULD NOT RETRIEVE BLAT OUTPUT: $resultFileFinal";
			}
			print "_"x6, "SIMILARITY 5 :: BLAT RESULT LOADED\n";

		} #for my $r



		my $h = 0;
		for (my $g = 0; $g <@{$Gresult}; $g++)
		{
			if (defined $Gresult->[$g]) { $h++ }
		}
		print "SIMILARITY 5 :: AFTER BLAT : $h INVALIDS\n";

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

		print "_"x4, "SIMILARITY 5 :: VALID: ", $resultValid," INVALID: ", $resultInValid,"\n";

		# 1=not ok null=ok


		my $queryStart = time;
		my $ldbh5 = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
				or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
		my $countResults = 0;
		for (my $r = 0; $r < @{$Gresult}; $r++)
		{
			if (defined $Gresult->[$r])
			{
				#print join("\t", @{$result}) . "\n";
				my $updateFirstFh = $ldbh5->prepare_cached($commandUpdate);
				   $updateFirstFh->execute($Gresult->[$r], $r);
				   $updateFirstFh->finish();
				$countResults++;
			}
		}
		$ldbh5->commit();
		$ldbh5->disconnect();

		print "_"x4, "SIMILARITY 5 :: UPDATE QUERY TIME : " , (time-$queryStart) , "s FOR ",$countResults," QUERIES\n";
		print "_"x4, "SIMILARITY 5 :: TOTAL TIME : ", (int((time - $startTime)+.5)), "s\n";

		return undef;
	}





#################
####### FOLD COMPLEXITY
#################
sub sthAnalizeFoldComplexity
{
	my $name          = $_[0];
	my $displayName   = $_[1];
	my $commandGet    = $_[2];
	my $commandUpdate = $_[3];
	my $startComplexity = time;
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
	print "_"x2, "COMPLEXITY :: FOLD COMPLEXITY ANALYSIS COMPLETED IN ", (int(time-$startComplexity)),"s\n\n\n";
}




sub analizeFoldComplexityRow
{
	my $startTime   = time;
	my @batch       = @{$_[0]};
	my $innerThread =   $_[1];
	my $commandUpdate = $_[2];
	my @results;


	my ($indexStartLig,				$indexStartM13,				$indexIdOrganism,				$indexSequenceLig,				$indexSequenceM13,				$indexId) =
	($oldColumnIndex{"startLig"}, $oldColumnIndex{"startM13"}, $oldColumnIndex{"idOrganism"}, $oldColumnIndex{"sequenceLig"}, $oldColumnIndex{"sequenceM13"}, $oldColumnIndex{"Id"});


	print "\t\tCOMPLEXITY :: THREAD $innerThread RUNNING WITH " . (scalar @batch) . " INPUTS\n";
	foreach my $row (@batch)
	{
		my @row      = @{$row};

		my $ligStart = $row[$indexStartLig];
		my $m13Start = $row[$indexStartM13];
		my $org      = $row[$indexIdOrganism];
		my $seqLig   = $row[$indexSequenceLig];
		my $seqM13   = $row[$indexSequenceM13];
		my $rowNum   = $row[$indexId];

		if ( ! defined $rowNum ) { die "ROWNUM NOT DEFINED"; };

		#my $seq      = $row[$newColumnIndex{"sequence"}];
		#my $ligant   = $row[$newColumnIndex{"ligant"}];

		#print "BEFORE $seqLig $seqM13\n";
		$seqLig    = &dnaCode::digit2dna($seqLig);
		$seqM13    = &dnaCode::digit2dna($seqM13);
		my $seq    = "$seqLig$seqM13";
		#my $ligant = substr($seqLig, -10) . substr($seqM13, 0, 10);

		#print "AFTER\n$seqLig.$seqM13\n$seq\n$ligant\n";

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
			#print " "x($m13StartRel-10) . "$ligant\n$seqLig.$seqM13\n";
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

#	print "UPDATE: $commandUpdate\n";

	foreach my $result (@results)
	{
		#print join("\t", @{$result}) . "\n";
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
	my $sthL      = 
#$ldbhGL->prepare_cached($commandGetSim2Results);
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

		my $seqLig   = $row[$oldColumnIndex{"sequenceLig"}];
		my $seqM13   = $row[$oldColumnIndex{"sequenceM13"}];
		my $rowNum   = $row[$oldColumnIndex{"Id"}];
		if ( ! defined $rowNum ) { die "ROWNUM NOT DEFINED"; };

		#my $seq      = $row[$newColumnIndex{"sequence"}];
		#my $ligant   = $row[$newColumnIndex{"ligant"}];

		#print "BEFORE $seqLig $seqM13\n";
		$seqLig    = &dnaCode::digit2dna($seqLig);
		$seqM13    = &dnaCode::digit2dna($seqM13);
		my $seq    = "$seqLig$seqM13";
		my $ligant = substr($seqLig, -10) . substr($seqM13, 0, 10);
		#$ligant    = &dna2digit($ligant);

		#print "AFTER\n$seqLig.$seqM13\n$seq\n$ligant\n";

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
		#print join("\t", @{$result}) . "\n";
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
		#print "ID $id LIGANT $ligant ORG $org\n";
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
				#foreach my $pos (@position) { print "$ligant $pos NOT EQUAL " . join(" ", @orgs) ."\n" };
			}
			else
			{
				foreach my $pos (@position) { $result[$pos][0] += 0; };
				$DoubleligantEqualCount++;
				#foreach my $pos (@position) { print "$ligant $pos EQUAL " . join(" ", @orgs) ."\n" };
				#print "\n";
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
		#print "TABLE HAS $numOfFields COLUMS\n\n";

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





#all fungi load
#start 1545
#end   1825
#total 0240
#580M data 833M index

#all fungi analysis - 3.2gb ram 4.3(threads)
#start 1827
#temp         3 min
#sim1        10 min
#compl      250 min (4h)
#end   		
#total      9861 (3h)


#	QUASIBLAST :: ANALIZING SIMILARITY
#		QUASIBLAST :: 1 : PHRASES LIST SIZE: 1665334 MINSIZE 9 MAXSIZE 14 AVGSIZE 12 WORD LENGTH: 4 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 1 : PHRASE VALID = 597392 PHRASE INVALID = 1067942 TOTAL PHRASES = 1665334
#		QUASIBLAST :: 2 : PHRASES LIST SIZE: 1665334 MINSIZE 13 MAXSIZE 17 AVGSIZE 15 WORD LENGTH: 5 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 2 : PHRASE VALID = 1665334 PHRASE INVALID = 0 TOTAL PHRASES = 1665334
#		QUASIBLAST :: 3 : PHRASES LIST SIZE: 1665334 MINSIZE 21 MAXSIZE 30 AVGSIZE 26 WORD LENGTH: 7 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 3 : PHRASE VALID = 1665334 PHRASE INVALID = 0 TOTAL PHRASES = 1665334
#		QUASIBLAST :: 4 : PHRASES LIST SIZE: 1665334 MINSIZE 8 MAXSIZE 8 AVGSIZE 8 WORD LENGTH: 3 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 4 : PHRASE VALID = 1665334 PHRASE INVALID = 0 TOTAL PHRASES = 1665334
#	QUASIBLAST :: VALID : 597391 INVALID : 1067942
#____SIMILARITY 1 :: VALID: 597392 INVALID: 1067942
#____SIMILARITY 1 :: UPDATE QUERY TIME : 148s FOR 1067942 QUERIES
#____SIMILARITY 1 :: TOTAL TIME : 567s

# NEW MATH
#	QUASIBLAST :: ANALIZING SIMILARITY
#		QUASIBLAST :: 1 : PHRASES LIST SIZE: 1665334 MINSIZE 9 MAXSIZE 14 AVGSIZE 12 WORD LENGTH: 4 MAX APPEARANCE: 4
#			QUASIBLAST :: RESULT : 1 : PHRASE VALID = 1296347 PHRASE INVALID = 368986 TOTAL PHRASES = 1665333
#		QUASIBLAST :: 2 : PHRASES LIST SIZE: 1665334 MINSIZE 13 MAXSIZE 17 AVGSIZE 15 WORD LENGTH: 5 MAX APPEARANCE: 4
#			QUASIBLAST :: RESULT : 2 : PHRASE VALID = 1292452 PHRASE INVALID = 3895 TOTAL PHRASES = 1296347
#		QUASIBLAST :: 3 : PHRASES LIST SIZE: 1665334 MINSIZE 21 MAXSIZE 30 AVGSIZE 26 WORD LENGTH: 9 MAX APPEARANCE: 5
#			QUASIBLAST :: RESULT : 3 : PHRASE VALID = 1292450 PHRASE INVALID = 2 TOTAL PHRASES = 1292452
#		QUASIBLAST :: 4 : PHRASES LIST SIZE: 1665334 MINSIZE 8 MAXSIZE 8 AVGSIZE 8 WORD LENGTH: 3 MAX APPEARANCE: 4
#			QUASIBLAST :: RESULT : 4 : PHRASE VALID = 0 PHRASE INVALID = 1292450 TOTAL PHRASES = 1292450
#	QUASIBLAST :: VALID : 0 INVALID : 1665333

