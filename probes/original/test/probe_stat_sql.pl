#!/usr/bin/perl -w
use strict;

use DBI;

#`/home/saulo/Desktop/rolf/sql/startSql.sh`;

my $limit     = 20;
my $host      = 'localhost';
my $database  = 'probe';
my $tablename = 'organism';
my $user      = 'probe';
my $pw        = '';


my $dbh = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>0, PrintError=>0, AutoCommit=>0,})
 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

&listTables();
&listViews();


$dbh->disconnect();


#getCoordinatesID($_[0], $_[1], $_[2], $_[3], $_[4], $_[5]);
#getProbeID($_[0]);
#getOrgID($_[0]);



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
		warn "PROBLEM RETRIEVING TABLE $database $tablename", $sth->errstr() ,"\n" if $sth->err();

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



1;
