#!/usr/bin/perl -w
use strict;

#use Mysql;
use DBI;

my $host      = 'localhost';
my $database  = 'probe';
my $tablename = 'organism';
my $user      = 'probe';
my $pw        = '';

# my $connect = Mysql->connect($host, $database, $user, $pw);

my $dbh = DBI->connect("DBI:mysql:$database", $user, $pw) or die "COULD NOT CONNECT TO DATABASE $database $user: $! $DBI::errstr";

print "TABLES\n";
my @tables = $dbh->tables();
print "\t" . join("\n\t",@tables) . "\n\n";




&addValue("c. albicans", "aaaaaaaaaccccccccccttttttttttggggggggggg", 1, 1, 5, 10, 15, 2);
&addValue("c. albicans", "aaaaaaaaaccccccccccttttttttttggggggggggg", 1, 1, 6, 10, 15, 2);
&addValue("c albicans",  "aaaaaaaaaccccccccccttttttttttggggggggggt", 1, 3, 5, 10, 15, 2);

sub addValue
{
	my $insertOrganism    = $dbh->prepare_cached("INSERT INTO organism    VALUES (NULL, ?)");
	my $insertProbe       = $dbh->prepare_cached("INSERT INTO probe       VALUES (NULL, ?)");
	my $insertCoordinates = $dbh->prepare_cached("INSERT INTO coordinates VALUES (NULL, ?, ?, ?, ?, ?, ?)");


	$insertOrganism->execute($_[0]);
	$insertProbe->execute($_[1]);
	$insertCoordinates->execute($_[2], $_[3], $_[4], $_[5], $_[6], $_[7]);
}




#$sth = $dbh->do("INSERT INTO probe    VALUES (NULL, candida albicans)");



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

$dbh->disconnect();
