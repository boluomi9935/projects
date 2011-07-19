#!/usr/bin/perl -w
use warnings;
use strict;

use lib "../filters";
use dnaPack;
use dnaCode;
use loadconf;
use DBIconnect;
my %pref = &loadconf::loadConf;
my $seqLen = 32;

my $indirTaxonomyFile = $pref{"indirTaxonomyFile"};	#IN ADITION TO INDIR
my $indir             = $pref{"indir"};

my $schemaName     = 'probe2';
my $tableName      = 'probe2';
my $columnName     = 'probe';
my $dropSchema     = "DROP SCHEMA IF EXISTS `$schemaName`";
my $createSchema   = "CREATE SCHEMA IF NOT EXISTS `$schemaName` DEFAULT CHARACTER SET latin1";
my $alterTableAdd  = "ALTER TABLE `$schemaName`.`$tableName` ADD COLUMN ? BOOLEAN  NOT NULL DEFAULT 0";
my $alterTableDrop = "ALTER TABLE `$schemaName`.`$tableName` DROP COLUMN ?";
my $selectTable    = "SELECT * FROM `$schemaName`.`$tableName`";

my $createTable = <<EOF
CREATE TABLE IF NOT EXISTS `$schemaName`.`$tableName` (
  `$columnName` CHAR(12) BINARY NOT NULL,
  PRIMARY KEY (`$columnName`)
)
DEFAULT CHARACTER SET = latin1
ENGINE                = InnoDB
COLLATE               = latin1_bin
MIN_ROWS              = 1000000000
AVG_ROW_LENGTH        = 150
PACK_KEYS             = 1
ROW_FORMAT            = DYNAMIC;
EOF
;


my $dbh  = &DBIconnect::DBIconnect();
&sthInsertCreate($dropSchema);
&sthInsertCreate($createSchema);
&sthInsertCreate($createTable);
my $existingColumns = &sthAnalizeStat($selectTable . " LIMIT 1");	# get result table
my $neededIds       = &genNeededIds($indir, $indirTaxonomyFile, $existingColumns);
my $notNeededIds    = &genNotNeededIds($existingColumns, $neededIds);

&workColumns($neededIds,    $alterTableAdd,  "ADD");
&workColumns($notNeededIds, $alterTableDrop, "DROP");
&saveIds($neededIds);

$dbh->commit();
$dbh->disconnect();






#my $sth5V = $dbh5->prepare($alterTable);
#$sth5V->execute();
#my $rowsV = $sth5V->rows;
#my $row;

#while($row = $sth5V->fetchrow_arrayref) {}


sub saveIds
{
	my $needed = $_[0];
	
	open NEED, ">needed.lst" or die "COULD NOT OPEN needed.lst TO SAVE: $!";
	
	foreach my $id (sort keys %{$needed})
	{
		print NEED $id, "\n";
	}
	
	close NEED;
}

sub workColumns
{
	my $list = $_[0];
	my $sql  = $_[1];
	my $act  = $_[2];
	
	foreach my $id (sort keys %{$list})
	{
		next if ( ! $list->{$id} );
		
		#my $updateFirstFh = $dbh->prepare_cached($alterTable);
		my $lAlterTable   = $sql;
		$lAlterTable      =~ s/\?/$id/;
	
		print "ALTERING TABLE WITH :: $act $id :: $lAlterTable\n";
	
		my $updateFirstFh = $dbh->prepare($lAlterTable);
		$updateFirstFh->execute() or die "COULD NOT EXECUTE $lAlterTable : $! : $DBI::errstr";
		$updateFirstFh->finish();
	}
}



sub genNotNeededIds
{
	my $lExistingColumns = $_[0];
	my $lNeededIds       = $_[1];
	my $lNotNeededIds;
	
	foreach my $id (sort keys %{$lExistingColumns})
	{
		#print "CHECKING NEED OF ID $id\n";
		next if ($id eq $columnName);
		if ( exists $lNeededIds->{$id} )
		{
			$lNotNeededIds->{$id} = 0;
			print "\tID $id NEEDED\n";
		}
		else
		{
			print "\tID $id NOT NEEDED\n";
			$lNotNeededIds->{$id} = 1;
		}
	}	
	
	
	return $lNotNeededIds;
}


sub genNeededIds
{
	my $lIndir             = $_[0];
	my $lIndirTaxonomyFile = $_[1];
	my $lExistingColumns   = $_[2];
	
	print "ITERATING OVER FILES AT $lIndir\n";
	opendir (DIR, "$lIndir") or die $!;
	my @infiles = grep /\.fasta$/, readdir(DIR);
	closedir DIR;
	
	if ( ! @infiles ) { die "NO FASTA FILES FOUND IN $indir DIRECTORY"};
	
	my $taxonomy  = &getTaxonomy($lIndirTaxonomyFile);
	
	my $fileCount = 1;
	my $fileTotal = scalar(@infiles);
	
	my $neededColumns;
	
	foreach my $file (@infiles)
	{
		my $id = "$taxonomy->{$file}[0].$taxonomy->{$file}[1]";
		$id =~ s/\./\_/;
		
		if ( exists $lExistingColumns->{$id} )
		{
			$neededColumns->{$id} = 0;
			print "\tALREADY IN THE DATABASE. SKIPPING";
		}
		else
		{
			$neededColumns->{$id} = 1;
			print "\tNOT IN THE DATABASE. ADDING";
		}
		printf " %-8s  %s\n", $id, $file;
	}
	
	return $neededColumns;
}


sub getTaxonomy
{
	my $file = $_[0];
	my %taxonomy;
	print "LOADING TAXONOMIC FILE $file...";
	
	open FILE, "<$file" or die "COULD NOT OPEN FASTA FILE $file: $!\n";
	my $count = 0;
	my $countValid = 0;
	while (<FILE>)
	{
		chomp;
		if (($count++) && ($_))
		{
			if (/.\t\d+\t\d+\t\d+/)
			{
				$countValid++;
				my ($fasta, $taxID, $variant, $fileType);
				($fasta, $taxID, $variant, $fileType) = split("\t",$_);
				if ((defined $fasta) && (defined $taxID) && (defined $variant) && (defined $fileType))
				{
			#		print "FASTA $fasta TAXID $taxID FILETYPE $fileType\n";
					$taxonomy{$fasta}[0] = $taxID;
					$taxonomy{$fasta}[1] = $variant;
					$taxonomy{$fasta}[2] = $fileType;
				}
			}
			elsif (/^#/)
			{
				
			}
			else
			{
				print "SKIPPED: ", $_, "\n"
			}
		}
	}
	print "DONE\n";
	print "\t$countValid FILES IN TAXONOMIC INDEX\n";
	return \%taxonomy;
}


sub sthInsertCreate
{
	my $insertTime = time;
	my @commands   = @_;

	print "INSERT :: RUNNING COMMANDS\n";
	#my $dbhI = DBI->connect("DBI:mysql:$vars{database}", $vars{user}, $vars{pw}, {RaiseError=>1, PrintError=>1, AutoCommit=>0}) or die "INSERT :: COULD NOT CONNECT TO DATABASE $vars{database} $vars{user}: $! $DBI::errstr";

	foreach my $command (@commands)
	{
		print "\tINSERT :: RUNNING COMMAND : $command\n";
		$dbh->do($command);
	}

	print "INSERT :: COMPLETED IN    : ", (time - $insertTime), "s\n";
	$dbh->commit();
	#$dbhI->disconnect();
}


sub sthAnalizeStat
{
	my $command = $_[0];
	print "_"x2, "STAT :: RETRIEVING TABLE INFORMATION\n";
	print "_"x4, "STAT :: RETRIEVING RESULT: $command\n";
    #my $dbhS = &DBIconnect::DBIconnect();
    
	my $sthS = $dbh->prepare($command);
	$sthS->execute() or die "COULD NOT EXECUTE $command : $! : $DBI::errstr";
	print "_"x4, "STAT :: RESULT RETRIEVED SUCCESSIFULLY\n";

    my %H_newColumnIndex;

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

		$H_newColumnIndex{$fieldName} = $f;
	}

	my $maxLen = 9;

	foreach my $key (sort keys %H_newColumnIndex)
	{
		if ( ! defined $H_newColumnIndex{$key} )
		{
			print "COULD NOT OBTAIN COLUM INDEX FOR $key\n";
			next;
		}
		$maxLen = length($key) if (length($key) > $maxLen);
	}

	print "_"x4, "STAT :: TOTAL COLUMNS : ", (scalar keys %H_newColumnIndex) , "\n";
	printf "\tNEW\n";

	foreach my $col (sort keys %H_newColumnIndex)
	{
		next if ( ! defined $H_newColumnIndex{$col} );
		printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", uc($col), $H_newColumnIndex{$col};
	}

	die "STAT :: PROBLEM RETRIEVING TABLE ", $sthS->errstr() ,"\n" if $sthS->err();

	$sthS->finish();
	$dbh->commit();

	print "_"x2, "STAT :: TABLE INFORMATION RETRIEVED\n\n\n";
	return \%H_newColumnIndex;
}

1;