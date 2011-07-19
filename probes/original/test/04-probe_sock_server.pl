#!/usr/bin/perl -w
##!/usr/bin/pperl -w
#TODO: TRY PPERL
use strict;
use IO::Socket;
use Net::hostent;              # for OO version of gethostbyaddr
use DB_File;
use Fcntl;

`sudo renice -20 $$`;
my $statingTime = time;

my $kidpid;
my $dbFile    = $ARGV[0] || "tmp";
my $dbFileLig = "$dbFile.lig.db";
my $dbFileM13 = "$dbFile.m13.db";
my $dbFilePro = "$dbFile.pro.db";

my %ligKey;
my %m13Key;
my %proKey;
my $verbose = 0;

# TODO: TRY DB_HASH
tie %ligKey, 'DB_File', undef, O_CREAT | O_RDWR, 0644, $DB_HASH or die "Unable to open dbm file $dbFile: $!";
tie %m13Key, 'DB_File', undef, O_CREAT | O_RDWR, 0644, $DB_HASH or die "Unable to open dbm file $dbFile: $!";
tie %proKey, 'DB_File', undef, O_CREAT | O_RDWR, 0644, $DB_HASH or die "Unable to open dbm file $dbFile: $!";

# my $PORT = 9000;     # pick something not in use

# my $server = IO::Socket::INET->new( Proto     => 'tcp',
# 									LocalPort => $PORT,
# 									Listen    => SOMAXCONN,
# 									Reuse     => 1,
# 									ReuseAddr => 1);

$| = 1;
my $countQ   = 0;
my $counter  = 10000;
my $tElapsed = 0;
my @answer;
my @queries;

unlink '/tmp/server.sock';
print "SERVER STARTED\n";
my $server = IO::Socket::UNIX->new( Local     => '/tmp/server.sock',
									Type      => SOCK_STREAM,
									Listen    => SOMAXCONN)
or die "cant setup server: $!";

die   "can't setup server" unless $server;
print "[Server $0 :: $$ accepting clients]\n";
$server->autoflush(1);

my $countcl;

my $lastTime = time;
my $go  = 1;
while ($go) 
{
	my $client = $server->accept() or die "Couldn't accept client: $!";
	$client->autoflush(1);

	while (<$client>) 
	{
		$countcl++;
		chomp;
		if (/^(.+)\t(.+)\t(.+)\t(.+)$/i) 
		{
			@answer     = (0, 0, 0);
			$queries[0] = $1;
			$queries[1] = $2;
			$queries[2] = $3;
			$queries[3] = $4;

			if ( ! (++$countQ % $counter) ) { print "$countQ [" . &getSpeed() . "]..."; };

			my $before = time;
			if ( ! ($ligKey{$queries[1]}++)) { $answer[0] = 1; };
			if ( ! ($m13Key{$queries[2]}++)) { $answer[1] = 1; };
			if ( ! ($proKey{$queries[3]}++)) { $answer[2] = 1; };
			my $elapsed = time - $before;
			$tElapsed += $elapsed;

			print $client $queries[0] . "\t" . join('', @answer) . "\n";
			print $client "\n\r";

			if ($verbose)
			{
				print "QUERY : $_\n";
				print "ANSWER: " . $queries[0] . "\t" . join('', @answer) . "\n";
			}

			last;
		}
		else
		{
			if		( /^list$/i       )	{	print "GOT LIST\n"; 		print $client &getList();		last;	}
			elsif	( /^count$/i      )	{	print "GOT COUNT\n"; 		print $client &getCount();		last;	}
			elsif	( /^listcount$/i  )	{	print "GOT LISTCOUNT\n";	print $client &getListCount();	last;	}
			elsif	( /^elapsed$/i    )	{	print "GOT ELAPSED\n";		print $client &elapsed();		last;	}
			elsif	( /quit|exit/i    )	{	print "GOT QUIT\n"; 		print $client "QUITTING\n";		last;	}
			elsif	( /^verbose$/i    )
			{
				print "GOT VERBOSE\n";
				$verbose = $verbose ? 0 : 1;
				print $client "VERBOSITY: $verbose\n";
				last;
			}
			elsif	( /^statistics$/i )
			{
				print "GOT STATISTICS\n";
				print $client "STATISTICS\n";
				print $client "QUERIES: $countQ\n";
				print $client "TIME   : " . &elapsed() . " s\n\n";
				print $client &getList();
				print $client &getCount();
				print $client &getListCount();
				last;
			}
			elsif	( /^shutdown$/i )
			{
				print "RECEIVED SHUTDOWN\n";
				print $client "SHUTDOWN STATISTICS\n";
				print $client "QUERIES: $countQ\n";
				print $client "TIME   : " . &elapsed() . " s\n\n";
	# 			print $Cclient &getList();
				print $client &getCount();
	# 			print $Cclient &getListCount();
				$go  = 0;
				last;
			}
			else
			{
				die "INVALID KEY\n";
				print "\t INVALID QUERY $_\n";
				print "RECEIVED UNK " . $_ . "\n";
				print $client reverse($_) . "\n";
				last;
			}
		} # END ELSE QUERY
	} # END WHILE CLIENT
# 	print "\t$countcl NEXT CLIENT\n";
	shutdown ($client, 2) or die "COULD NOT CLOSE CLIENT: $!";
	$client->close()      or die "COULD NOT CLOSE CLIENT: $!";
# 	print "\t$countcl CLIENT CLOSED\n\n";
} #END WHILE GO
$server->close();



my $countL = (keys %ligKey);
my $countM = (keys %m13Key);
my $countK = (keys %proKey);

#RESUME
print $countQ . " QUERIES ANALIZED\n";
print $countL . " LIG PROBES GENERATED\n";
print $countM . " M13 PROBES GENERATED\n";
print $countK . " UNIQUE PROBES GENERATED\n";


my %ligKey2;
my %m13Key2;
my %proKey2;

unlink($dbFileLig);
unlink($dbFileM13);
unlink($dbFilePro);

tie %ligKey2, 'DB_File', $dbFileLig, O_CREAT | O_RDWR, 0644, $DB_BTREE or die "Unable to open dbm file $dbFile: $!";
tie %m13Key2, 'DB_File', $dbFileM13, O_CREAT | O_RDWR, 0644, $DB_BTREE or die "Unable to open dbm file $dbFile: $!";
tie %proKey2, 'DB_File', $dbFilePro, O_CREAT | O_RDWR, 0644, $DB_BTREE or die "Unable to open dbm file $dbFile: $!";

%ligKey2 = %ligKey;
%m13Key2 = %m13Key;
%proKey2 = %proKey;

untie %ligKey2;
untie %m13Key2;
untie %proKey2;






sub getSpeed
{
	my $currentT = time;
	my $elapsedT = $currentT - $lastTime;
	my $speed    = int($counter / $elapsedT);
	my $return   = "$speed probes/s{$tElapsed}";
	$lastTime    = $currentT;
	$tElapsed    = 0;
	return $return;
}


sub getGo
{
	my $go = shift;
	print $go "go\n";
	my $ans = <$go>;
	return $ans;
}


sub getList
{
# LIST
	my $ll = "LIST: \n";
	$ll    = "LIG\n" . join("\t", keys %ligKey). "\n";
	$ll   .= "M13\n" . join("\t", keys %m13Key). "\n";
	$ll   .= "PRO\n" . join("\t", keys %proKey). "\n\n";

	return $ll
}

sub getCount
{
#COUNT
	my $cc   = "COUNT: \n";
	my $cLig = (keys %ligKey); $cc  = "LIG: $cLig\n";
	my $cM13 = (keys %m13Key); $cc .= "M13: $cM13\n";
	my $cPro = (keys %proKey); $cc .= "PRO: $cPro\n\n";
	return $cc;
}

sub getListCount
{
#LISTCOUNT
	my $lc   = "LIST COUNT: \n";
	my $cLig = (keys %ligKey);
	$lc     .= "LIG: $cLig\n";
	foreach my $key (sort keys %ligKey)
	{
		$lc .= "\t$key > " . $ligKey{$key} . "\n";
	}

	my $cM13 = (keys %m13Key);
	$lc     .= "M13: $cM13\n";
	foreach my $key (sort keys %m13Key)
	{
		$lc .= "\t$key > " . $m13Key{$key} . "\n";
	}

	my $cPro = (keys %proKey);
	$lc     .= "PRO: $cPro\n";
	foreach my $key (sort keys %proKey)
	{
		$lc .= "\t$key > " . $proKey{$key} . "\n";
	}
	$lc .= "\n";
	return $lc;
}

sub elapsed
{
	my $elapsed = time - $statingTime;
	return $elapsed;
}

1;