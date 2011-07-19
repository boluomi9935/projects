#!/usr/bin/perl -w
use strict;
use threads;
use threads::shared;

my $splitSize  = 18_000_000;
my $suffix     = "aaaa";
my $prefix     = "biota";
my $outDir     = "out/";
my $compLevel  = 5; # 1 - 9
my $partition  = 4;
my $napTime    = 5;
my $maxThreads = $partition;

my $sTime       = time;
my $totalLines  = 0;
my $totalLinesM = 0;
my $totalOutput = 0;

my $currentFile;
my $fh;

my $files = &getFiles();

my $fileCluster = &splitFiles($files);

my $threadCount = 0;
for (my $c = 0; $c < @{$fileCluster}; $c++)
{
	#&runFileHash($fileCluster->[$c], $threadCount++);
	&newThread(\&runFileHash, $fileCluster->[$c], $threadCount++);
}

&waitThread();




sub splitFiles
{
	my $fileHash = $_[0];
	my @clusters;
	
	my $total = scalar(keys %{$fileHash});
	my $part  = int(($total / $partition) + .5) + 1;
	
	print "TOTAL $total PARTITIONED IN $partition PARTS OF $part EACH\n";
	my $cCount = 0;
	my $kCount = 1;
	foreach my $key (sort {$fileHash->{$a} <=> $fileHash->{$b}} keys %{$fileHash})
	{
		$clusters[$cCount++]{$key} = $fileHash->{$key};
		if ( $cCount == $partition ) { $cCount = 0; };
		$kCount++;
	}

	for (my $c = 0; $c < @clusters; $c++)
	{
		print "\tCLUSTER $c HAS ", scalar(keys %{$clusters[$c]}), " VALUES WITH ";
		my $totalSize = 0;
		foreach my $key (keys %{$clusters[$c]})
		{
			$totalSize += -s $key;
		}
		print "$totalSize BYTES IN TOTAL\n";
	}

	return \@clusters;
}

sub runFileHash
{
	my $fileHash   = $_[0];
	my $threadNum  = $_[1];
	my $totalFiles = scalar(keys %{$fileHash});
	my $countFiles = 1;
	
	$suffix = &getSuffix($threadNum);
	print "[$threadNum] STARTING @ $suffix\n";
	
	foreach my $file (sort {$fileHash->{$a} <=> $fileHash->{$b}} keys %{$fileHash})
	{
		open FILE, "<$file" or die "COULD NOT OPEN FILE $file : $!";
		print " === [$threadNum - $suffix] READING FILE $file ",$fileHash->{$file}," bytes [$countFiles / $totalFiles] ===\n";
		while (my $line = <FILE>)
		{
			printOutFile(\$line, $threadNum);
		}
		close FILE;
		
		print "\t\t[$threadNum] PACKING FILE $file TO $file.gz\n";
		`gzip -$compLevel $file`;
		
		print "\t\t[$threadNum] MOVING FILE $file.gz TO stock/$file.gz\n";
		move("$file.gz", "stock/$file.gz");
		
		$countFiles++;
	}
	
	print "\n\n[$threadNum] ",
	  ""      , ($totalLinesM * 18), " MILLONS",
	  " and " , $totalLines        , " LINES EXPORTED",
      " FROM ", $totalFiles        , " INPUT WC FILES",
	  " TO "  , $totalOutput       , " FILES",
	  " IN "  , (time - $sTime)    , "s\n";
}



sub getFiles
{
	opendir (DIR, "./") or die "FAILED TO OPEN DIR ./: $!";
	my @infiles = grep /\.wc$/, readdir(DIR);
	closedir DIR;
	my @insizes = map {-s} @infiles;
	my %files;
	
	for (my $f = 0; $f < @infiles; $f++)
	{
		$files{$infiles[$f]} = $insizes[$f];
	}
	
	return \%files;
}

sub printOutFile
{
	my $line      = $_[0];
	my $threadNum = $_[1];
	
	if (( ! ($totalLines % $splitSize) ) || ($totalLines == 0))
	{
		if (defined $fh )
		{
			close $fh;
			print "\t[$threadNum] CLOSING FH OF $currentFile\n";
		
			print "\t[$threadNum] PACKING FINISHED FILE $currentFile\n";
			`gzip -$compLevel $currentFile`;
			print "\t[$threadNum] FINISHED FILE $currentFile PACKED\n\n";
		}

		$currentFile = "$outDir$prefix\_$suffix.wc";		
		print "[$threadNum] OPENNING $currentFile [$totalOutput]\n";
		open ($fh, '>', "$currentFile") or die "COULD NOT OPEN $prefix\_$suffix.wc TO STORE: $!";

		print "[$threadNum] STARTING PRINTING TO $currentFile\n";
		print $fh $$line;

		$totalOutput++;
		$totalLines = 1;
		$totalLinesM++;
		$suffix++;
	}
	else
	{
		$totalLines++;
		print $fh $$line;
	}
}















sub newThread
{
	my $function   = $_[0];
	my @parameters = @_[1 .. (scalar(@_) - 1)];
	
	while (threads->list(threads::running) > ($maxThreads - 1 ))
	{
		sleep($napTime); 
	}

	foreach my $thr (threads->list(threads::joinable))
	{
		$thr->join();
	}

	threads->new($function, @parameters);
}


sub waitThread
{
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



sub getSuffix
{
	my $thread = $_[0];
	my @sufList;
	$sufList[0] = "aaaa";
	$sufList[1] = "bbbb";
	$sufList[2] = "cccc";
	$sufList[3] = "dddd";
	$sufList[4] = "eeee";
	$sufList[5] = "ffff";
	$sufList[6] = "gggg";
	$sufList[7] = "hhhh";
	
	return $sufList[$thread];
}

1;