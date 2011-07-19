#!/usr/bin/perl -w
use strict;
use DBI;
use lib "./filters";
use complexity;
use folding;
use similarity;
use threads;
use threads::shared;
use threads 'exit'=>'threads_only';

#############################
### SETUP
#############################
my $originalView  = "v_originalFinal";
my $originalTable = "t_originalFinal";

my $limit     = 20;
my $host      = 'localhost'; 
my $database  = 'probe';
my $user      = 'probe';
my $pw        = '';
my $batchInsertions = 10000; # number of batch insertions

#	COLUMN NAME		TYPE	SIZE	OPTIONS	[0=1ST 1=2ND RUN]
my @newColumns = 
(
	["Complexity",     "INT",   "1", "UNSIGNED", 0],
	["Folding",        "INT",   "3", "UNSIGNED", 0],
	["FoldingLig",     "INT",   "3", "UNSIGNED", 0],
	["FoldingM13",     "INT",   "3", "UNSIGNED", 0],
	["AnalysisResult", "INT",   "4", "UNSIGNED", 0],
	["Ligant",         "CHAR", "20", "BINARY",   1],
	["LigantUnique",   "INT",   "1", "UNSIGNED", 1]
);

my $maxThreads = 4;
my $napTime    = 1;

#############################
### INITIATION
#############################
my $addColumn   = "";
my $insertInto  = "";
my $insertExtra = "";
#my $updateFirstFh;
#my $updateExtraFh;
my $countRow = 0;
my ($indLS, $indMS, $indL, $indM, $indOrg, $indId);
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

	$addColumn .= ",\nADD COLUMN $name $type";
	$addColumn .= " ($size)" if $size;
	$addColumn .= " $extra"  if $extra;

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
#$originalTable = "t_originalFinal200905061739";

my @dnaKey;
my %keyDna;
my @DIGIT_TO_CODE;
my %CODE_TO_DIGIT;


#############################
### SQL STATEMENTS
#############################
my $dbh = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

my $commandGetResult     = "SELECT * FROM $originalTable";
my $commandCreatTable    = "CREATE TABLE \`probe\`.\`$originalTable\` ENGINE InnoDB SELECT * FROM \`probe\`.\`$originalView\`";
my $commandAddColumn     = "ALTER  TABLE \`probe\`.\`$originalTable\` ADD COLUMN Id INT UNSIGNED NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (Id)$addColumn"; 
my $commandUpdateFields  = "UPDATE \`probe\`.\`$originalTable\` SET $insertInto WHERE Id = ?";
my $commandUpdateLigants = "UPDATE \`probe\`.\`$originalTable\` SET ligant = ? WHERE Id = ?";


#############################
### PROGRAM
#############################
&loadVariables();
&sthInsertCreate(); # create table out of result view

my $resultFh = $dbh->prepare($commandGetResult);
&sthGetResult($resultFh);		# get result table
&sthAnalyzeFirst($resultFh);	# analyze anything that can be done row by row.
								# update the table at the end automatically
								# threaded
$resultFh->finish();


my $resultFh2 = $dbh->prepare($commandGetResult);
&sthAnalyzeExtra($resultFh2); 	# analyze anything that needs extra data handling
								# the update must be done individually
								# any threading must be done individually
$dbh->disconnect();





#######################################
####### CORE FUNCTIONS
#######################################

sub sthInsertCreate
{
	print "CREATING MYSQL RESULT TABLE\n";
	$dbh->do($commandCreatTable);
	$dbh->do($commandAddColumn);
	print "TIMESTAMP $timeStamp\n";
}

sub sthGetResult
{
	my $resultFh = $_[0];
	print "RETRIEVING RESULT\n";

	$resultFh->execute();
	&sthAnalizeStat($resultFh);

	print "RESULT RETRIEVED SUCCESSIFULLY\n";
}

sub sthAnalyzeFirst
{
	my $resultFh = $_[0];
	print "STARTING FIRST STEP OF ANALYSIS\n";

	&sthAnalizeFoldComplexity($resultFh);

	print "FIRST STEP OF ANALYSIS DONE\n";
}


sub sthAnalyzeExtra
{
	print "STARTING SECOND STEP OF ANALYSIS\n";

	&sthGenerateLigants($resultFh);
	&analyzeLigants();

	print "SECOND STEP OF ANALYSIS DONE\n";
}







#######################################
####### EXTRA FUNCTIONS
#######################################

sub sthAnalizeStat
{
	my $sth = $_[0];
	my $numOfFields = $sth->{NUM_OF_FIELDS};

	my @fields;
	for (my $f = 0; $f < $numOfFields; $f++)
	{
		my $fieldName = $sth->{NAME}->[$f];
		push(@fields, $fieldName);
	}

	for (my $i = 0; $i < @fields; $i++)
	{ 
		my $field = $fields[$i];
		if ($field eq "startLig")     { $indLS  = $i; }
		if ($field eq "startM13")     { $indMS  = $i; }
		if ($field eq "sequenceLig")  { $indL   = $i; }
		if ($field eq "sequenceM13")  { $indM   = $i; }
		if ($field eq "nameOrganism") { $indOrg = $i; }
		if ($field eq "Id")           { $indId  = $i; }
		if (exists $newColumnIndex{$field}) {$newColumnIndex{$field} = $i};
	}

	my $maxLen = 9;
	foreach my $col (keys %newColumnIndex)
	{
		$maxLen = length($col) if (length($col) > $maxLen);
	}

	if ( ! ((defined $indId) && (defined $indOrg) && (defined $indM) && (defined $indL) && (defined $indMS) && (defined $indLS))) { die "COULD NOT OBTAIN COLUMNS INDEX. CHECK COLUMN NAMES"; };
	print "THERE ARE:\n";
	print "\t" . @fields . " COLUMNS\n";
	print "\tOLD\n";
	printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "LIG START", $indLS;
	printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "M13 START", $indMS;
	printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "LIG SEQ",   $indL;
	printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "M13 SEQ",   $indM;
	printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "ORGANISM",  $indOrg;
	printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", "ID",        $indId;
	printf "\tNEW\n";

	foreach my $col (sort keys %newColumnIndex)
	{
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", uc($col), $newColumnIndex{$col};
		if ( ! (defined $newColumnIndex{$col})) { die "NEW COLUMN $col NOT FOUND\n"; };
	}

	die "PROBLEM RETRIEVING TABLE $database", $sth->errstr() ,"\n" if $sth->err();
}


sub sthAnalizeFoldComplexity
{
	my $sth       = $_[0];
	   $countRow  = 0;
	my @batch;

	while(my $row = $sth->fetchrow_arrayref) 
	{
		$countRow++;
		if ( (scalar @batch) == $batchInsertions )
		{
			my @row = @{$row};
			push(@batch, \@row);
			print "\tANALYZING ROW # $countRow\n";
			while (threads->list(threads::running) > ($maxThreads-1))
			{
				sleep($napTime); 
			}

			foreach my $thr (threads->list(threads::joinable))
			{
				$thr->join();
			}
			print "\t\tSTARTING THREAD $threadCount ($countRow)\n";
			threads->new(\&analizeFoldComplexityRow, (\@batch, $threadCount));
			$threadCount++;
			@batch = ();
		}
		else
		{
			my @row = @{$row};
			push(@batch, \@row);
		};
	}
	print "\t\tSTARTING LAST THREAD $threadCount\n";
	threads->new(\&analizeFoldComplexityRow, (\@batch, $threadCount));
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
}




sub analizeFoldComplexityRow
{
	my $startTime   = time;
	my @batch       = @{$_[0]};
	my $innerThread =   $_[1];
	my @results;

	print "\t\tTHREAD $innerThread RUNNING WITH " . (scalar @batch) . " INPUTS\n";
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
		$seqLig    = &digit2dna($seqLig);
		$seqM13    = &digit2dna($seqM13);
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
	my $ldbh = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $countResults = 0;
	foreach my $result (@results)
	{
#		print join("\t", @{$result}) . "\n";
		my $updateFirstFh = $ldbh->prepare_cached($commandUpdateFields);
		   $updateFirstFh->execute(@{$result});
		   $updateFirstFh->finish();
		$countResults++;
	}
	$ldbh->commit();
	$ldbh->disconnect();

	print "\t\t\tUPDATE QUERY FOR THREAD $innerThread TOOK " . (time-$queryStart) . "s FOR $countResults QUERIES\n";
	print "\t\tTHREAD $innerThread HAS FINISHED (" . (time-$startTime) . "s)\n";
	return undef;
}



sub sthGenerateLigants
{
	my $sth       = $_[0];
	   $countRow  = 0;
	my @batch;

	while(my $row = $sth->fetchrow_arrayref) 
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
}

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
		$seqLig    = &digit2dna($seqLig);
		$seqM13    = &digit2dna($seqM13);
		my $seq    = "$seqLig$seqM13";
		my $ligant = substr($seqLig, -10) . substr($seqM13, 0, 10);
#		$ligant    = &dna2digit($ligant);

#		print "AFTER\n$seqLig.$seqM13\n$seq\n$ligant\n";

		#print join("\t", @row[0 .. 15]) . " > $rowNum\n";

		my @newData = ($ligant, $rowNum);
		push(@results, \@newData);
	} # end foreach my row



	my $queryStart = time;
	my $ldbh = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0})
			or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $countResults = 0;
	foreach my $result (@results)
	{
#		print join("\t", @{$result}) . "\n";
		my $updateFirstFh = $ldbh->prepare_cached($commandUpdateLigants);
		   $updateFirstFh->execute(@{$result});
		   $updateFirstFh->finish();
		$countResults++;
	}
	$ldbh->commit();
	$ldbh->disconnect();

	print "\t\t\tUPDATE QUERY TOOK " . (time-$queryStart) . "s FOR $countResults QUERIES\n";
	return undef;
}


sub analyzeLigants
{
	my $commandUpdateExtra = "UPDATE \`probe\`.\`$originalTable\` SET LigantUnique = ?, AnalysisResult = (AnalysisResult + ?) WHERE Id = ?";
	my $commandGetLigant   = "SELECT Id, Ligant, nameOrganism FROM $originalTable";
	my %ligantSeen;



	print "\tANALYZING LIGANTS\n";	
	my $ligantsTime = time;
	my $queryStart  = time;	
	my $ldbh        = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>1, PrintError=>1, AutoCommit=>0}) or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";
	my $resultFh    = $ldbh->prepare($commandGetLigant);
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
		my $updateExtraFh = $ldbh->prepare_cached($commandUpdateExtra);
		   $updateExtraFh->execute($value, $result, $k);
		#if   ($result[$k] > 1) { printf "%20s => %02d\t", ${$rows}[$k][$indLig], $result[$k]; if ( ! ($kc++ % 5)) {print "\n"; }; }
	}
	$ldbh->commit();
	$ldbh->disconnect();
	print "\t\tUPDATING TABLE COMPLETED IN " . (time - $updateTime) . "s\n";

	print "\tLIGANTS ANALYSIS COMPLETED IN " . (time - $ligantsTime) . "s\n";
	print "\tVALID: $valid\tNOT VALID: $notValid\n";
}




























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

	foreach my $sth (@lists)
	{
		$sth->execute();
		my $numOfFields = $sth->{NUM_OF_FIELDS};
		#my @table       = @{$sth->{'mysql_table'}};
#		print "TABLE HAS $numOfFields COLUMS\n\n";

		#print "register";
		my @fields;
		my @fieldSize;
		for (my $f = 0; $f < $numOfFields; $f++)
		{
			my $fieldName = $sth->{NAME}->[$f];
			#print "$fieldName   ";
			push(@fields, $fieldName);
			$fieldSize[$f][0] = length($fieldName);
		}
		#print "\n";

		my $countRow = 1;

		my @values;
		while (my @row = $sth->fetchrow_array())
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
		warn "PROBLEM RETRIEVING TABLE $database", $sth->errstr() ,"\n" if $sth->err();

		if ($sth->rows == 0)
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
		$sth->finish();
	}
}





#######################################
####### TOOLBOX FUNCTIONS
#######################################
sub listViews
{
	my @lists;

	push(@lists, $dbh->prepare_cached("SELECT *                            FROM countUnique LIMIT $limit"));
	push(@lists, $dbh->prepare_cached("SELECT *                            FROM original LIMIT $limit"));
	push(@lists, $dbh->prepare_cached("SELECT COUNT(*) as TotalOriginal    FROM original"));
	push(@lists, $dbh->prepare_cached("SELECT *                            FROM probeUniqId LIMIT $limit"));
	push(@lists, $dbh->prepare_cached("SELECT COUNT(*) as TotalProbeUniqId FROM probeUniqId"));

	&sthExecute(@lists);
}


sub listTables
{
	print "TABLES\n";
	my @tables = $dbh->tables();
	print "\t" . join("\n\t",@tables) . "\n\n";

	my @lists;
	push(@lists, $dbh->prepare_cached("SELECT *                            FROM organism"));
	push(@lists, $dbh->prepare_cached("SELECT COUNT(*) as TotalOrganisms   FROM organism"));
	push(@lists, $dbh->prepare_cached("SELECT *                            FROM probe LIMIT 5"));
#	push(@lists, $dbh->prepare_cached("SELECT COUNT(*) as TotalProbes      FROM probe"));
	push(@lists, $dbh->prepare_cached("SELECT *                            FROM coordinates LIMIT 5"));
#	push(@lists, $dbh->prepare_cached("SELECT COUNT(*) as TotalCoordinates FROM coordinates"));


	&sthExecute(@lists);
}














sub getCoordinatesID
{
	if (! (defined $_[0])) { die "PROBE    ID  NOT DEFINED ON getCoordinatesID\n"};
	if (! (defined $_[1])) { die "ORGANISM ID  NOT DEFINED ON getCoordinatesID\n"};
	if (! (defined $_[2])) { die "STARTLIG POS NOT DEFINED ON getCoordinatesID\n"};
	if (! (defined $_[3])) { die "STARTM13 POS NOT DEFINED ON getCoordinatesID\n"};
	if (! (defined $_[4])) { die "ENDM13   POS NOT DEFINED ON getCoordinatesID\n"};
	if (! (defined $_[5])) { die "CHROMOSSOME  NOT DEFINED ON getCoordinatesID\n"};

	my $coordId = $dbh->prepare_cached("SELECT idcoordinates FROM coordinates WHERE probe_idprobe = ? AND organism_idorganism = ? AND startLig = ? AND startM13 = ? AND endM13 = ? AND chromossome = ?");

	$coordId->execute($_[0], $_[1], $_[2], $_[3], $_[4], $_[5]);

#	warn "PROBLEM RETRIEVING $database $tablename COORDINATES ID $_[0] ", $coordId->errstr() ,"\n" if $coordId->err();

	my @row = $coordId->fetchrow_array();

	if (@row != 1)
	{
		die "INCONSISTENCY IN NUMBER OF FIELDS ON COORDENADES ID: " . @row . " " . join(" ", @row) . "\n";
	}
#	else
#	{
#		print "FIELDS " . @row . " " . join(" ", @row) . "\n";
#	}

	my $id = $row[0];

	if ( ! (defined $id))
	{
		die "COULD NOT RETRIEVE COORD ID";
	}
#	else
#	{
#		print "COORD ID $id\n";
#	}

	$coordId->finish();

	return $id;
}




sub getProbeID
{
	if (! (defined $_[0])) { die "PROBE NOT DEFINED ON gerProbeID\n"};
	my $probeId  = $dbh->prepare_cached("SELECT idprobe FROM probe WHERE sequence = ?");

	$probeId->execute($_[0]);
#	warn "PROBLEM RETRIEVING $database $tablename PROBE ID $_[0] ", $probeId->errstr() ,"\n" if $probeId->err();

	my @row = $probeId->fetchrow_array();

	if (@row != 1)
	{
		die "INCONSISTENCY IN NUMBER OF FIELDS ON PROBE ID: " . @row . " " . join(" ", @row) . "\n";
	}
#	else
#	{
#		print "FIELDS " . @row . " " . join(" ", @row) . "\n";
#	}

	my $id = $row[0];


	if ( ! (defined $id))
	{
		die "COULD NOT RETRIEVE PROBE ID";
	}
#	else
#	{
#		print "PROBE ID $id\n";
#	}

	$probeId->finish();

	return $id;
}




sub getOrgID
{
	if (! (defined $_[0])) { die "ORGANISM NOT DEFINED ON getOrgID\n"};
	my $organismId = $dbh->prepare_cached("SELECT idorganism FROM organism WHERE nameOrganism = ?");

	$organismId->execute($_[0]);
#	warn "PROBLEM RETRIEVING ORGANISM ID $database $tablename $_[0] ", $organismId->errstr() ,"\n" if $organismId->err();

	my @row = $organismId->fetchrow_array();

	if (@row != 1)
	{
		die "INCONSISTENCY IN NUMBER OF FIELDS ON ORGANISM ID: " . @row . " " . join(" ", @row) . "\n";
	}
#	else
#	{
#		print "FIELDS " . @row . " " . join(" ", @row) . "\n";
#	}

	my $id = $row[0];

	if ( ! (defined $id))
	{
		die "COULD NOT RETRIEVE ORGANISM ID";
	}
#	else
#	{
#		print "ORGANISM ID $id\n";
#	}

	$organismId->finish();

	return $id;
}










sub compDigit($$)
{
	my $digit1 = $_[0];
	my $digit2 = $_[1];

	my $digit1S;
	my $digit2S;
	($digit1S, ) = &splitDigit($digit1);
	($digit2S, ) = &splitDigit($digit2);

	my $digit2Rc  = &digit2digitrc($digit2);
	my $digit2SRc = &digit2digitrc($digit2S);
	my $digit1Rc  = &digit2digitrc($digit1);
	my $digit1SRc = &digit2digitrc($digit1S);

	print "\tCOMPARING NORMAL vs NORMAL: ", $digit1, " WITH ", $digit2, "\n";
	if ($digit1 =~ /$digit2/) { return 1; };
	if ($digit2 =~ /$digit1/) { return 1; };

	print "\tCOMPARING NORMAL vs RC: ", $digit1, " WITH ", $digit2Rc, "\n";
	if ($digit2Rc =~ /$digit1/)   { return 2; };
	if ($digit1   =~ /$digit2Rc/) { return 2; };

	print "\tCOMPARING STRIPED vs STRIPED: ", $digit1S, " WITH ", $digit2S, "\n";
	if ($digit1S =~ /$digit2S/) { return 3; };
	if ($digit2S =~ /$digit1S/) { return 3; };

	print "\tCOMPARING STRIPED vs NORMAL RC: ", $digit1S, " WITH ", $digit2Rc, "\n";
	if ($digit2Rc =~ /$digit1S/)  { return 4; };
	if ($digit1Rc =~ /$digit2S/)  { return 4; };
	if ($digit2S  =~ /$digit1Rc/) { return 4; };
	if ($digit1S  =~ /$digit2Rc/) { return 4; };

	print "\tCOMPARING STRIPED vs STRIPED RC: ", $digit1S, " WITH ", $digit2SRc, "\n";
	if ($digit1    =~ /$digit2SRc/) { return 5; };
	if ($digit2SRc =~ /$digit1/)    { return 5; };

	return 0;
}

sub digit2digitrc($)
{
	my $digit = $_[0];
	my $dna   = &revComp(&digit2dna($digit));
	return &dna2digit($dna);
}

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

sub digit2dna($)
{
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
		$outSeq    .= $dnaKey[$CODE_TO_DIGIT{$subSeq}];
	}

# 	print "$outSeq (" . length($outSeq) . ") -> ";
	$outSeq .= $extra;
# 	print "$outSeq (" . length($outSeq) . ")\n\n";
	return $outSeq;
}

sub revComp($)
{
	my $sequence = uc($_[0]);
	my $rev = reverse($sequence);
	$rev =~ tr/ACTG/TGAC/;
	return $rev;
}

sub dna2digit($)
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
#	my @dnaRevKey;
	foreach my $st ("A", "C", "G", "T")
	{
		foreach my $nd ("A", "C", "G", "T")
		{
			foreach my $rd ("A", "C", "G", "T")
			{
				my $seq = "$st$nd$rd";
				push(@dnaKey, $seq);
#				push(@dnaRevKey, &revComp($seq));
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
