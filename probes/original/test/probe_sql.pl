#!/usr/bin/perl -w
use strict;

use DBI;

#`/home/saulo/Desktop/rolf/sql/startSql.sh`;

my $host      = 'localhost';
my $database  = 'probe';
my $tablename = 'organism';
my $user      = 'probe';
my $pw        = '';


my $dbh = DBI->connect("DBI:mysql:$database", $user, $pw, {RaiseError=>0, PrintError=>0, AutoCommit=>1,})
 or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";


#&listAll();

my @species   = ("c. albicans", "c albicans", "cry albicans", "cry albicans");
my @sequences = ("aaaaaaaaaccccccccccttttttttttggggggggggg", "ccccccccccttttttttttgggggggggggaaaaaaaaa", "ttttttttttgggggggggggaaaaaaaaacccccccccc", "ttttttttttgggggggggggaaaaaaaaacccccccccc");
my @positions = (['1', '1', '5', '10', '15', '2'],
		 ['1', '1', '6', '10', '15', '2'],
		 ['1', '5', '5', '10', '15', '2']);

foreach my $spp (@species)
{
	foreach my $sequence (@sequences)
	{
		foreach my $pos (@positions)
		{
#			&addValue($sequence, $spp, @{$pos});
		}
	}
}



&listAll();
$dbh->disconnect();
print "gracifully\n";






sub addCoordinates
{
	if (! (defined $_[0])) { die "PROBE    ID  NOT DEFINED ON addCoordinates\n"};
	if (! (defined $_[1])) { die "ORGANISM ID  NOT DEFINED ON addCoordinates\n"};
	if (! (defined $_[2])) { die "STARTLIG POS NOT DEFINED ON addCoordinates\n"};
	if (! (defined $_[3])) { die "STARTM13 POS NOT DEFINED ON addCoordinates\n"};
	if (! (defined $_[4])) { die "ENDM13   POS NOT DEFINED ON addCoordinates\n"};
	if (! (defined $_[5])) { die "CHROMOSSOME  NOT DEFINED ON addCoordinates\n"};

	my $tablename   = "coordinates";
	my $insertCoord = $dbh->prepare_cached("INSERT INTO coordinates VALUES (NULL, ?, ?, ?, ?, ?, ?)");

	$insertCoord->execute($_[0], $_[1], $_[2], $_[3], $_[4], $_[5]);
#	warn "PROBLEM EXECUTING INSERT $database $tablename COORDINATES $_[0] ", $insertCoord->errstr() ,"\n" if $insertCoord->err();
	my $response = $insertCoord->rows;
	
	if ( ! defined $response)
	{
		print "NOT OK (undef) FOR $_[0]:\n";
		die "ERROR ACESSING DATABASE $database $tablename TO INSERT COORD $_[0]: $! $DBI::errstr";
	}
	elsif ( $response == 0)
	{
		print "IF NOT OK (0): DATABASE ERROR FOR $_[0]: $response\n";
		die "ERROR ACESSING DATABASE $database $tablename TO INSERT COORD $_[0]: $! $DBI::errstr";
	}
#	elsif ( $response == -1)
#	{
#		print "IF NOT OK (-1): DUPLICATE FOR COORD $_[0]: $response\n";
#	}
#	elsif ( $response == 1)
#	{
#		print "IF OK (1): INSERTED FOR COORD $_[0]: $response\n";
#	}
#	else
#	{
#		print "IF UNKNOWN FOR COORD $_[0]: $response\n";
#	};

	$insertCoord->finish();

	return getCoordinatesID($_[0], $_[1], $_[2], $_[3], $_[4], $_[5]);
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


sub addProbe
{
	if (! (defined $_[0])) { die "PROBE NOT DEFINED ON addProbe\n"};
	my $tablename   = "probe";
	my $insertProbe = $dbh->prepare_cached("INSERT INTO probe VALUES (NULL, ?)");

	$insertProbe->execute($_[0]);
#	warn "PROBLEM EXECUTING INSERT $database $tablename PROBE $_[0] ", $insertProbe->errstr() ,"\n" if $insertProbe->err();
	my $response = $insertProbe->rows;
	
	if ( ! defined $response)
	{
		print "NOT OK (undef) FOR $_[0]:\n";
		die "ERROR ACESSING DATABASE $database $tablename TO INSERT PROBE $_[0]: $! $DBI::errstr";
	}
	elsif ( $response == 0)
	{
		print "IF NOT OK (0): DATABASE ERROR FOR $_[0]: $response\n";
		die "ERROR ACESSING DATABASE $database $tablename TO INSERT PROBE $_[0]: $! $DBI::errstr";
	}
#	elsif ( $response == -1)
#	{
#		print "IF NOT OK (-1): DUPLICATE FOR PROBE $_[0]: $response\n";
#	}
#	elsif ( $response == 1)
#	{
#		print "IF OK (1): INSERTED FOR PROBE $_[0]: $response\n";
#	}
#	else
#	{
#		print "IF UNKNOWN FOR PROBE $_[0]: $response\n";
#	};

	$insertProbe->finish();

	return getProbeID($_[0]);
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


sub addOrganism
{
	if (! (defined $_[0])) { die "ORGANISM NOT DEFINED ON addOrganism\n"};
	my $tablename         = "organism";
	my $insertOrganism    = $dbh->prepare_cached("INSERT INTO organism VALUES (NULL, ?)");


	$insertOrganism->execute($_[0]);
#	warn "PROBLEM EXECUTING INSERT $database $tablename ORGANISM $_[0] ", $insertOrganism->errstr() ,"\n" if $insertOrganism->err();
	my $response = $insertOrganism->rows;
	
	if ( ! defined $response)
	{
		print "NOT OK (undef) FOR $_[0]:\n";
		die "ERROR ACESSING DATABASE $database $user $tablename TO INSERT ORGANISM $_[0]: $! $DBI::errstr";
	}
	elsif ( $response == 0)
	{
		print "IF NOT OK (0): DATABASE ERROR FOR $_[0]: $response\n";
		die "ERROR ACESSING DATABASE $database $user $tablename TO INSERT ORGANISM $_[0]: $! $DBI::errstr";
	}
#	elsif ( $response == -1)
#	{
#		print "IF NOT OK (-1): DUPLICATE FOR ORGANISM $_[0]: $response\n";
#	}
#	elsif ( $response == 1)
#	{
#		print "IF OK (1): INSERTED FOR ORGANISM $_[0]: $response\n";
#	}
#	else
#	{
#		print "IF UNKNOWN FOR ORGANISM $_[0]: $response\n";
#	};


	return getOrgID($_[0]);
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



sub addValue
{
	if (! (defined $_[0])) { die "PROBE    NAME NOT DEFINED ON addValue\n"};
	if (! (defined $_[1])) { die "ORGANISM NAME NOT DEFINED ON addValue\n"};
	if (! (defined $_[2])) { die "STARTLIG POS  NOT DEFINED ON addValue\n"};
	if (! (defined $_[3])) { die "STARTM13 POS  NOT DEFINED ON addValue\n"};
	if (! (defined $_[4])) { die "ENDM13   POS  NOT DEFINED ON addValue\n"};
	if (! (defined $_[5])) { die "CHROMOSSOME   NOT DEFINED ON addValue\n"};


	my $probeid    = &addProbe($_[0]);
	my $organismid = &addOrganism($_[1]);
	my $coordid    = &addCoordinates($probeid, $organismid, $_[2], $_[3], $_[4], $_[5]);

	return ($probeid, $organismid, $coordid);
}


sub addValue2
{
	my $insertOrganism    = $dbh->prepare_cached("INSERT INTO organism    VALUES (NULL, ?)");
	my $insertProbe       = $dbh->prepare_cached("INSERT INTO probe       VALUES (NULL, ?)");
	my $insertCoordinates = $dbh->prepare_cached("INSERT INTO coordinates VALUES (NULL, ?, ?, ?, ?, ?, ?)");


	$insertOrganism->execute($_[0]);
	$insertProbe->execute($_[1]);
	$insertCoordinates->execute($_[2], $_[3], $_[4], $_[5], $_[6], $_[7]);
}



sub listAll
{
	print "TABLES\n";
	my @tables = $dbh->tables();
	print "\t" . join("\n\t",@tables) . "\n\n";




	# my $query = "SELECT * FROM $tablename WHERE user = ?";
	#my $query = "SELECT * FROM $tablename";
	# $dbh->do($query)                 or die "COULD NOT DO      $database $user $query: $! $DBI::errstr";
	# DO IS FOR REQUESTS WITHOUT RETURN




	#my $sth = $dbh->prepare($query)  or die "COULD NOT PREPARE $database $user $query: $! $DBI::errstr";
	# $sth->execute("saulo")                  or die "COULD NOT EXECURE $database $user $query: $! $DBI::errstr";
	#$sth->execute()                  or die "COULD NOT EXECURE $database $user $query: $! $DBI::errstr";
	# PREPARE AND EXECUTE ARE FOR REQUESTS WITH A RETURN

	my $listOrganism    = $dbh->prepare_cached("SELECT * FROM organism");
	my $listProbe       = $dbh->prepare_cached("SELECT * FROM probe");
	my $listCoordinates = $dbh->prepare_cached("SELECT * FROM coordinates");

	my @lists = ($listOrganism, $listProbe, $listCoordinates);

	foreach my $sth (@lists)
	{
		$sth->execute();
		my $numOfFields = $sth->{NUM_OF_FIELDS};
		print "NUM OF FIELDS:\n\t$numOfFields\n\n";

		print "register";
		for (my $f = 0; $f < $numOfFields; $f++)
		{
			my $fieldName = $sth->{NAME}->[$f];
			print "  $fieldName";
		}
		print "\n";


		my $countRow = 1;

		while (my @row = $sth->fetchrow_array())
		{
			#print "@row\n";
			print $countRow++ . "\t";
			for (my $co = 0; $co < @row; $co++)
			{
				print $row[$co] . "\t";
			}
			print "\n";
		}
		print "\n"x2;
		warn "PROBLEM RETRIEVING TABLE $database $tablename", $sth->errstr() ,"\n" if $sth->err();



	#	my ($ho, $us, $pwd);
		# $sth->bind_columns (\$ho, \$us, \$pwd, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef);
	#	$sth->bind_col(1, \$ho);
	#	$sth->bind_col(2, \$us);
		# $sth->bind_col(3, \$pwd);
	#	while ($sth->fetch())
	#	{
	#		print "organism: $us\tid: $ho\n";
	#	}
	#	warn "PROBLEM RETRIEVING TABLE $database ", $sth->errstr() ,"\n" if $sth->err();

		if ($sth->rows == 0)
		{
			print "NO NAMES MATCHED\n";
		}

		$sth->finish();
	}
}

1;
