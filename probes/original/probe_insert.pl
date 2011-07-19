#!/usr/bin/perl -w
use strict;
use warnings;
use lib "./filters";
use filters::loadconf;
my %pref = &loadconf::loadConf;

&loadconf::checkNeeds(
"currentDir",      "indir",           "storageDir",     "mysqlCmd",
"storageDirInput", "storageDirInput"
);

my $currentDir           = $pref{"currentDir"};
my $indir                = $pref{"indir"};
my $storageDir 			 = $pref{"storageDir"};
my $mysqlCmd             = $pref{"mysqlCmd"};
my $storageDirInput	     = $pref{"storageDirInput"};	
my $storageDirDumps		 = $pref{"storageDirDumps"};	
$mysqlCmd = $mysqlCmd;

&run();
sleep(15);
&run();

sub run
{
	do 
	{
		my @files = &checkSQL();
		do
		{
			foreach my $inFile (@files)
			{
				my $inFileFull = "$storageDirInput/$inFile";
				print "INSERTING SQL: ", $inFileFull, "\n";
				my $retry = 0;
				while ( &insertSQL($inFileFull) )
				{
					$retry++;
					print "\t$inFileFull RETRY #$retry\n";
				}
			}
			sleep(5);
		} 	while (@files = &checkSQL());
		print "WAITING FOR SQL WHILE THERE'S STILL XML DUMP";
		sleep(5);
	} while (&checkXML());
}

sub renameSQL
{
	my $oldName = $_[0];
	my $newName = "$oldName";
	   $newName =~ s/.sql$/.did/;
#	print "\tRENAMING FILE $oldName TO $newName\n";
	rename($oldName, $newName) or die "COULD NOT RENAME FILE $oldName TO $newName";
}

sub insertSQL
{
	my $inFile     = $_[0];
	my $cmd        = "$mysqlCmd < $inFile";
	system($cmd);
	my $out        = $?;
	if ($out == 0)
	{
		&renameSQL($inFile);
	}
#	print "RUNNING $cmd WITH OUT $out\n";
	return $out;
}

sub checkSQL
{
	opendir (INPUTDIR, $storageDirInput) || die "COULD NOT OPEN DUMP DIR: $storageDirInput: $!";
	my @files = grep(/\.sql/i, readdir(INPUTDIR));
	closedir(INPUTDIR);

	#print "THERE ARE ", scalar(@files) , " SQL FILES YET: ", join(", ", @files) , "\n\n\n";

	return @files;
}


sub checkXML
{
	opendir (DUMPDIR, $storageDirDumps) || die "COULD NOT OPEN DUMP DIR: $storageDirDumps: $!";
	my @files = grep(/\.xml/i, readdir(DUMPDIR));
	closedir(DUMPDIR);

#	print "THERE ARE ", scalar(@files) , " DUMP FILES YET: ", join(", ", @files) , "\n\n\n";

	return scalar(@files);
}


1;
