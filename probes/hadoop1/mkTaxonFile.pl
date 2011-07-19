#!/usr/bin/perl -w
use strict;
use lib "./filters";
use DBIconnect;

my @tax;
my $taxonomyFolder = "/home/saulo/Desktop/rolf/input";
my $taxonomyFile   = "taxonomy.idx";
my $taxonomyDb     = "taxonomy";
my $taxonomyTable  = "taxonomy";
my $onlyIfExists   = 1;

$taxonomyFile = $taxonomyFolder . "/" . $taxonomyFile;
#$tax[taxon id][0] = parent taxon id
#$tax[taxon id][1] = steps to root (deepness) - rank number
#$tax[taxon id][2] = rank name
#$tax[taxon id][3] = name
#$tax[taxon id][4] = @children

#open taxonomy.idx
#extract ids
#query genealogy to sql db
#export file

my $taxonomy = &getTaxonomy($taxonomyFile);

my $dbh                                   = &DBIconnect::DBIconnect($taxonomyDb);
(my $taxonLevelHash, my $taxonLevelArray) = &loadTaxonLevel();
my $columIndexHash                        = &sthAnalizeStat("SELECT taxonomy.* FROM `$taxonomyDb`.`$taxonomyTable` LIMIT 1");
my $sql                                   =
	"SELECT $taxonomyTable.* FROM `$taxonomyDb`.`$taxonomyTable`, "  .
	"("                                                              .
		"SELECT left_value as innerLeft, right_value as innerRight " .
		"FROM `$taxonomyDb`.`$taxonomyTable` "                       .
		"WHERE "                                                     .
			"ncbi_taxon_id = (?) AND "                               .
			"name_class = \"scientific name\""                       .
	") AS insider "                                                  .
	"WHERE "                                                         .
		"$taxonomyTable.left_value  <= insider.innerLeft  AND "      .
		"$taxonomyTable.right_value >= insider.innerRight AND "      .
		"name_class = \"scientific name\" AND "                      .
		"node_rank <> \"no rank\" "                                  .
	"ORDER BY left_value";

#SELECT taxonomy.* FROM `taxonomy`.`taxonomy`, (SELECT left_value as innerLeft, right_value as innerRight FROM `taxonomy`.`taxonomy` WHERE ncbi_taxon_id = "100474" AND name_class = "scientific name") AS insider WHERE taxonomy.left_value  <= insider.innerLeft  AND taxonomy.right_value >= insider.innerRight AND name_class = "scientific name" AND node_rank <> "no rank" ORDER BY left_value;


my $queryFh = $dbh->prepare($sql);

my $count    = 1;

$tax[0][0] = undef;
$tax[0][1] = 0;
$tax[0][2] = $taxonLevelArray->[0];
$tax[0][3] = "god";


while ((my $k, my $v) = each (%{$taxonomy}))
{
	my $id = $v->[0];
	print "ID #",$count++," $id LOADED\n";

	$queryFh->execute($id) or die "COULD NOT EXECUTE $sql : $! : $DBI::errstr";

	my $idColumnIndex   = $columIndexHash->{"NCBI_TAXON_ID"};
	my $rankColumnIndex = $columIndexHash->{"NODE_RANK"};
	my $nameColumnIndex = $columIndexHash->{"NAME"};
	my $countRow        = 0;

	my $lastId = 0;
	while(my $row = $queryFh->fetchrow_arrayref)
	{
		$countRow++;

		my $id    = $row->[$idColumnIndex];
		my $rank  = $row->[$rankColumnIndex];
		my $level = $taxonLevelHash->{$rank}[0];
		my $name  = $row->[$nameColumnIndex];
		next if ( ! defined $taxonLevelArray->[$level] );

		$tax[$id][0] = $lastId;
		$tax[$id][1] = $level;
		$tax[$id][2] = $taxonLevelArray->[$level];
		$tax[$id][3] = $name;

		printf "\tTAXON ID: %7d LASTID: %7d RANK: %14s LEVEL: %02d NAME: %s\n", $id, $lastId, $rank, $level, $name;

		$lastId  = $id;
	}

	#last if $count == 10;
}

$queryFh->finish();
$dbh->commit();
$dbh->disconnect();




my @outString;
my @outStringV;
for (my $deep = scalar(keys %{$taxonLevelHash}); $deep > 0; $deep--)
{
	my @todo;
	for (my $id = 0; $id < @tax; $id++)
	{
		next if (( ! defined $tax[$id][0] ) || ( ! defined $tax[$id][1] ));

		if ($tax[$id][1] == $deep)
		{
			my $parentId = $tax[$id][0];
			push(@{$todo[$parentId]},   $id);
			push(@{$tax[$parentId][4]}, $id);
		}
	}

	for (my $t = 0; $t < @todo; $t++)
	{
		my $children = $todo[$t];
		next if ! defined $children;
		next if ! defined $tax[$t][0];
		my $name   = $tax[$t][3];
		my $rank   = $tax[$t][2];
		my $rankId = $tax[$t][1];
		my $parent = $tax[$t][0];
		my $pName  = $tax[$tax[$t][0]][3];
		my $childA = $tax[$t][4];


		my $outString  = "$rankId\t$t\t";
		   $outString .= join(",", @{$childA});
		   $outString .= "\n";

		my $outStringV  = "$rank\[$rankId\]\t$name\[$t\]\t";

		push(@{$outString[$rankId]}, $outString);

		print "TAXON $t ", $name, " (",$rank," - ",$rankId,") WITH PARENT ", $parent, " [", $pName ,"] HAS THE FOLLOWING CHILDREN:\n";
		if (defined @{$childA})
		{
			map { printf "\t%7d - %s\n",$_,$tax[$_][3]; } sort {$a <=> $b} @{$childA};
			my $str;
			foreach my $child (@{$childA})
			{
				$str .= "," if (defined $str);
				$str .= $tax[$child][3] . "\[$child\]";
			}
			$outStringV .= $str . "\n";
		}
		else
		{
			print "\tnone\n";
		}

		push(@{$outStringV[$rankId]}, $outStringV);
	}
}

open OUT, ">taxonomy.tab" or die "COULD NOT OPEN taxonomy.tab: $!";
open OUTV, ">taxonomy.verbose.tab" or die "COULD NOT OPEN taxonomy.verbose.tab: $!";
for (my $o = @outString; $o >= 0; $o--)
{
	next if ( ! defined $outString[$o] );
	my @array = @{$outString[$o]};
	foreach my $out (@array)
	{
		print OUT $out;
	}

	my @arrayV = @{$outStringV[$o]};
	foreach my $out (@arrayV)
	{
		print OUTV $out;
	}
}
close OUTV;
close OUT;





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
					if ( ( ! -f "$taxonomyFolder/$fasta" ) && ($onlyIfExists) )
					{
						print "\tSKIPPING FILE $fasta. DOESNT EXISTS\n";
						next;
					}
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

		$H_newColumnIndex{uc($fieldName)} = $f;
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

	print "_"x2, "STAT :: TABLE INFORMATION RETRIEVED",scalar(keys %H_newColumnIndex),"\n\n\n";
	return \%H_newColumnIndex;
}


sub loadTaxonLevel
{
	#level id children
	#http://en.wikipedia.org/wiki/Taxonomic_rank

	my %taxLevels;
	my @taxLevels;

$taxLevels{"biota"}                            = [ qw(  0 0 ) ];
	$taxLevels{"superkingdom"}                 = [ qw(  1 1 ) ];
		$taxLevels{"kingdom"}                  = [ qw(  2 1 ) ];
			$taxLevels{"subkingdom"}           = [ qw(  3 0 ) ];
	$taxLevels{"superphylum"}                  = [ qw(  4 0 ) ];
		$taxLevels{"phylum"}                   = [ qw(  5 1 ) ];
			$taxLevels{"subphylum"}            = [ qw(  6 0 ) ];
	$taxLevels{"superclass"}                   = [ qw(  7 0 ) ];
		$taxLevels{"class"}                    = [ qw(  8 1 ) ];
			$taxLevels{"subclass"}             = [ qw(  9 0 ) ];
				$taxLevels{"infraclass"}       = [ qw( 10 0 ) ];
	$taxLevels{"superorder"}                   = [ qw( 11 0 ) ];
		$taxLevels{"order"}                    = [ qw( 12 1 ) ];
			$taxLevels{"parvorder"}            = [ qw( 13 0 ) ];
				$taxLevels{"suborder"}         = [ qw( 14 0 ) ];
					$taxLevels{"infraorder"}   = [ qw( 15 0 ) ];
	$taxLevels{"superfamily"}                  = [ qw( 16 0 ) ];
		$taxLevels{"family"}                   = [ qw( 17 1 ) ];
			$taxLevels{"subfamily"}            = [ qw( 18 0 ) ];
				$taxLevels{"tribe"}            = [ qw( 19 0 ) ];
					$taxLevels{"subtribe"}     = [ qw( 20 0 ) ];
	$taxLevels{"genus"}                        = [ qw( 21 1 ) ];
		$taxLevels{"subgenus"}                 = [ qw( 22 0 ) ];
			$taxLevels{"species group"}        = [ qw( 23 0 ) ];
				$taxLevels{"species subgroup"} = [ qw( 24 0 ) ];
	$taxLevels{"species"}                      = [ qw( 25 1 ) ];
		$taxLevels{"subspecies"}               = [ qw( 26 1 ) ];
			$taxLevels{"varietas"}             = [ qw( 27 1 ) ];
				$taxLevels{"forma"}            = [ qw( 28 1 ) ];

	$taxLevels{"node_rank"}                    = [ qw( 29 0 ) ]; #viruses
	$taxLevels{"no rank"}                      = [ qw( 30 0 ) ]; #various

	while ((my $k, my $v) = each (%taxLevels))
	{
		$taxLevels[$v->[0]] = $k if ($v->[1]);
	}

	return (\%taxLevels, \@taxLevels);
}

1;
