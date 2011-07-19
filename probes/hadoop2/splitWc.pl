#!/usr/bin/perl -w
use strict;
use threads;
use threads::shared;
use File::Copy;

#my $splitSize  = 18_000_000; # to generate 64mb output compressed files. 18M lines for 32bp and level 5 gzip
#my $splitSize  = 22_000_000; # to generate 64mb output compressed files. 22M lines for 24bp and level 5 gzip
#my $splitSize   =  2_250_000; # to generate 64mb output compressed files. 22M lines for 24bp and level 5 gzip mlpa
my $splitSize   = 10_050_000; # to generate 64mb output compressed files. 22M lines for 24bp and level 5 gzip mlpa

my $prefix     = "biota";
my $outDir     = "out/";
my $ext        = "had";
my $partition  = 3; # how many pieces the files have to be splitted in order to multithread
my $napTime    = 5; # time between two queries of how many threads have finish in order to start a new thread
my $zip        = 0; # 1 = unpak and read 0 = read
my $packResult = 0; # pack result file or not

my $extOrig    = $ext;
if ( $zip ) { $ext .= ".gz"; };

my $indir      = "input/";
my $compLevel  = 5; # 1 - 9
my $agregator  = "agregator_hadoop.pl";
my $gzip       = "/usr/bin/gzip";
my $gunzip     = "/usr/bin/gzip -d";
#my $sort       = "sort -k 1,8  --compress-program=gzip"; # compressed mlpa
my $sort       = "sort -k 1,30  --compress-program=gzip"; # uncompressed pcr
my $grepDual   = "grepDual.pl";
my $maxThreads = $partition;
my $justSecond = 1;


my $sTime       = time;
my $totalLines  = 0;
my $totalLinesM = 0;
my $totalOutput = 0;

my $currentFile;

my $files                = &getFiles();
my ($fhHash, $namesHash) = &getFHHash() if ( ! $justSecond );
my $fileCluster          = &splitFiles($files);

for (my $c = 0; $c < @{$fileCluster}; $c++)
{
	#&runFileHash($fileCluster->[$c], $c);
	&runFileHash($fileCluster->[$c], $c) if ( ! $justSecond );
	#&newThread(\&runFileHash, $fileCluster->[$c], $c);
}

&waitThread();

&closeFHHash($fhHash) if ( ! $justSecond );
&packResult($namesHash);

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
		if ( $cCount == $partition) { $cCount = 0; };
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


sub getFHHash
{
	my %fhHash;
	my %nameHash;
	my @voca = ("A" , "C", "G", "T");

	foreach my $st (@voca)
	{
		foreach my $nd (@voca)
		{
			foreach my $rd (@voca)
			{
				my $fileName = "$outDir$prefix\_$st$nd$rd.$extOrig";
				print "OPENING OUT FILENAME $fileName\n";
				open(my $fh, ">$fileName") or die "COULD NOT OPEN FILE $fileName : $!";
				$fhHash{$st.$nd.$rd} = $fh;
				$nameHash{$fileName} = 1;
			}
		}
	}

	return (\%fhHash, \%nameHash);
}

sub closeFHHash
{
	my $hash = $_[0];
	foreach my $key (keys %$hash)
	{
		print "CLOSING OUTPUT FILE FOR \"$key\" SEQUENCES\n";
		my $value = $hash->{$key};
		close $value;
	}
}


sub runFileHash
{
	my $fileHash   = $_[0];
	my $threadNum  = $_[1];
	my $totalFiles = scalar(keys %{$fileHash});
	my $countFiles = 1;

	print "[$threadNum]\n";
	$0 .= " :: [$threadNum]";

	foreach my $file (sort {$fileHash->{$a} <=> $fileHash->{$b}} keys %{$fileHash})
	{
		my $fh;
		if ( $zip )
		{
			#open(FILE, "/usr/bin/gunzip -c $file |") or die "COULD NOT OPEN FILE $file : $!";
			$fh = "$gunzip -c $file |";
		}
		else
		{
			$fh = "<$file";
			#open(FILE, "<$file") or die "COULD NOT OPEN FILE $file : $!";
		}

		die "NOT DEFINED FH" if ( ! defined $fh );

		print " ===   [$threadNum] READING FILE $file ",$fileHash->{$file}," bytes [$countFiles / $totalFiles] ===\n";
		open(FILE, $fh) or die "COULD NOT OPEN FILE $file : FH $fh : $!";

		while (<FILE>)
		{
			die "NO LINE 1 : $_" if ( ! defined $_ );
			die "NO LINE 2 : $_" if ( ! $_ );

			my $fh = $fhHash->{substr($_, 0, 3)};
			print $fh $_;
		}

		print "   --- [$threadNum] CLOSING FILE $file ",$fileHash->{$file}," bytes [$countFiles / $totalFiles] ---\n";
		close FILE or die "COULD NOT CLOSE $file";

		if ( ! $zip )
		{
			print "\t\t[$threadNum] PACKING FILE $file TO $file.gz\n";
			#`$gzip -$compLevel $file &`;
		}

		$countFiles++;
	}

	print "[$threadNum] ENDED\n";

	print "\n\n[$threadNum]",
	  ""      , ($totalLinesM * ($splitSize / 1_000_000)), " MILLIONS",
	  " and " , $totalLines                , " LINES EXPORTED",
	  " FROM ", $totalFiles                , " INPUT ",uc($ext)," FILES",
	  " TO "  , $totalOutput               , " FILES",
	  " IN "  , (time - $sTime)            , "s\n";
}



sub getFiles
{
	opendir (DIR, "$indir") or die "FAILED TO OPEN DIR $indir: $!";
	my @infiles = grep /\.$ext$/, readdir(DIR);
	closedir DIR;

	my %files;
	for (my $fc = 0; $fc < @infiles; $fc++)
	{
		if ( -f  $indir . $infiles[$fc] )
		{
			$files{$indir . $infiles[$fc]} = -s $indir . $infiles[$fc];
		}
		else
		{
			die "FILE ",  $indir . $infiles[$fc], " DOESNT EXISTS";
		}
	}

	return \%files;
}


sub packResult
{
	my $nameHash = $_[0];

	foreach my $currentFile (keys %$nameHash)
	{
		my $finalCmd = " | $outDir/$grepDual $currentFile.sort.ag.shared.had $currentFile.sort.ag.unique.had \\;";
		if ( $packResult )
		{
			 $finalCmd = "; $gzip -$compLevel $currentFile.sort.ag.*.had";
		}

		&newThread(\&runPackCmd, $currentFile, $finalCmd);
	}
}

sub runPackCmd
{
	my $currentFile = $_[0];
	my $finalCmd    = $_[1];
	print "\tPACKING FINISHED FILE $currentFile\n";

	print "\t\tCMD: cat $currentFile | $sort | $outDir/$agregator 2>$currentFile.err $finalCmd\n\t",
	`cat $currentFile | $sort | $outDir/$agregator 2>$currentFile.err $finalCmd`, "\n";
	`rm -f $currentFile`;

	print "\tFINISHED FILE $currentFile PACKED\n\n";
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

1;
