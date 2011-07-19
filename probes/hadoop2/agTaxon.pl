#!/usr/bin/perl -w
use strict;
use threads;
use threads::shared;
use File::Copy;

##############################################################################
#################################### SETUP ###################################
##############################################################################
# to generate 64mb output compressed files. 18M lines for 32bp and level 5 gzip
#my $splitSize = 18_000_000;
# to generate 64mb output compressed files. 22M lines for 24bp and level 5 gzip
my $splitSize  = 22_000_000; 

my $suffix     = "aaa";
my $prefix     = "biota";
my $outDir     = "out/";

my $verbose      = 0;
my $file         = '/home/saulo/Desktop/rolf/rolf2/taxonomy.verbose.tab';
#my $file        = '/home/saulo/Desktop/rolf/rolf2/taxonomy.tab';
my $indir        = '/home/saulo/Desktop/rolf/rolf2/wc/output';
my $outdir       = '/home/saulo/Desktop/rolf/rolf2/wc/taxon';
my $agregator    = "$outDir/agregator.pl";
my $agregatorSpp = "$outDir/agregatorSpp.pl";

my $serious    = 1;  # real or test
my $compLevel  = 5;  # 1 - 9
my $partition  = 4;  # how many pieces the files have to be splitted
					 # in order to multithread
my $napTime    = 5;  # time between two queries of how many threads have
					 # finish in order to start a new thread
my $maxThreads = $partition;
my $overwrite  = 0;  # overwrite if output file exists
my $pack       = 1;  # pack or not output files
my $minSize    = 25; # minimmum size in bytes of output to be consided "not empty"

my $sTime       = time;
my $totalLines  = 0;
my $totalLinesM = 0;
my $totalOutput = 0;

my $currentFile;
my $fh;

my $packCmdStdin = '';
my $packCmdFile  = '';
my $unPackCmd    = '';
my $packExt      = '';
my $catCmd       = 'cat ';
my $normalExt    = 'wc';

if ($pack)
{
	$packCmdStdin = " | gzip -c -$compLevel ";
	$packCmdFile  = "gzip -$compLevel ";
	$unPackCmd    = " gunzip -cd ";
	$packExt      = ".gz";
}

my $orig  = "$normalExt.sort.ag";  # extension of output
my $shar  = "$orig.shared"; # extension of shared file
my $uniq  = "$orig.unique"; # extension of unique file
   $orig .= $packExt;



##############################################################################
################################### PROGRAM ##################################
##############################################################################
my ($taxArray, $taxNamesArray, $levelsNamesArray) = &getTaxArray($file);
my %descendants;

#merge variants of same species as a single file containing only shared
#sequences
&mergeSpp();

#goes over each taxonomic level, from bottom (species) to top (kingdom)
for (my $level = (@$taxArray - 1); $level >=0; $level--)
{
	next if ( ! defined $taxArray->[$level]);

	#if ($level > 17) { $serious = 0 } else { $serious = 1};
	#last if ($level <= 16 );

	my $localArray = $taxArray->[$level];
	
	print "LEVEL ", $levelsNamesArray->[$level], ":\n";
	
	# export a given level
	&exportLevel($localArray);
}





##############################################################################
################################### LIBRARY ##################################
##############################################################################
sub exportLevel
{
	my $localArray  = $_[0];

	for (my $parentId = (@$localArray - 1); $parentId >= 0; $parentId--)
	{
		next if ( ! defined $localArray->[$parentId]);
		my $localKids = $localArray->[$parentId];
		print " "x2 , "TAXID: ", $taxNamesArray->[$parentId],
		      " [", scalar @$localKids," kids]\n";

		my $files = "";
		
		#list files of a given list of id
		my $kidHaveFile = &getKidsFiles($localKids, $parentId);

		#if found "root" files, put all of them to be concatenated for analysis
		if (scalar (keys %{$kidHaveFile->{wc}}))
		{
			map { $files .= "$_.$normalExt$packExt "; } (keys %{$kidHaveFile->{wc}});
		}

		#change the program to read input files from "cat" to "gzip"
		my $cat = '';
		if ($pack)
		{
			$cat = $unPackCmd;
		}
		else
		{
			$cat = $catCmd;
		}


		#if there are shared/unique files, concatenate shared or unique
		#(whatever has output) to analysis
		if (scalar (keys %{$kidHaveFile->{sh}}))
		{
			foreach my $kid (keys %{$kidHaveFile->{sh}})
			{
				if ( ! exists $kidHaveFile->{wc}{$kid} )
				{
					foreach my $kFile ("$kid.$shar$packExt", "$kid.$uniq$packExt")
					{
						if ($kidHaveFile->{sh}{$kid}{$kFile})
						{
							$files .= "$kFile ";
							last;
						}
					} # end foreach my kid file
				} # end if exists wc
			} # end foreach my kid
		} # end if the are shared files


		if (( ! ((scalar (keys %{$kidHaveFile->{wc}}))   ||
				 (scalar (keys %{$kidHaveFile->{sh}})))) && ($serious))
		{
			warn "NO FILES TO ANALYZE";
			next;
		}


		my $totalLocalKids   = scalar @$localKids;
		my $totalDescendants = (scalar keys %{$descendants{$parentId}});
		print " "x4 , "TAXID: ", $taxNamesArray->[$parentId],
		" HAS ", $totalLocalKids,
		" DIRECT KIDS AND ", $totalDescendants,
		" INDIRECT SONS AND DOUGHTERS\n";
		
		foreach my $desce ( keys %{$descendants{$parentId}} )
		{
			print " "x6 , "\t",$taxNamesArray->[$desce],"\n";
		}

		#generate list of all original species codes which makes the current level
		if (scalar (keys %$kidHaveFile))
		{
			my $name    = $taxNamesArray->[$parentId];

			if ($files eq "")
			{
				warn "NO FILES TO ANALYZE... SKIPPING\n";
				next;
			}

			my $greps = '';
			if (( $totalLocalKids > 1 ) || ( $totalDescendants > 1))
			{
				foreach my $desce ( keys %{$descendants{$parentId}} )
				{
					# grep for the code not followed nor preceded by any number
					#$greps .= " | grep -e " . '\'[^\d]' . $desce . '[^\d]\'';
					$greps .= ' [^\\d]' . $desce . '[^\\d]';
				}
			}
			# ! TAKE CARE ! :
			#02LBOBN]	552467_0,552467_1
			#02LB[r2+	5207_0,5207_2
			# they will appear as shared by the family when they
			# are shered by the species only
			
			#export final list to parent id file
			#&export($cat, $files, $parentId, $greps, $name);
			&newThread(\&export, $cat, $files, $parentId, $greps, $name);

		}#end if file
		&waitThread();
	}#end for each patent id
	&waitThread();
}



sub export
{
	my $cat      = $_[0];
	my $files    = $_[1];
	my $parentId = $_[2];
	my $greps    = $_[3];
	my $name     = $_[4];
	
	my $cmd1 = "$cat  " . "  $files "            . " | sort -k 1,8   " . " | $agregator " . "$packCmdStdin" . " > \"$parentId.$orig\"";
	#my $cmd2 = "$cat  " . "\"$parentId.$orig\" " . " | grep    \",\" " . "   $greps     " . "$packCmd" . " > \"$parentId.$shar\"";
	#my $cmd3 = "$cat  " . "\"$parentId.$orig\" " . " | grep -v \",\" " . ""               . "$packCmd" . " > \"$parentId.$uniq\"";
	
	my $cmd2 = "$cat  " . "\"$parentId.$orig\" " . " | ./grepDual.pl \"$parentId.$shar\" \"$parentId.$uniq\"  , " . $greps;
	my $cmd3 = "$packCmdFile \"$parentId.$shar\"; $packCmdFile \"$parentId.$uniq\"";

	
	my $cmd4 = "ln -s " . "\"$parentId.$orig\" "         . " \"$name.$orig\"";
	my $cmd5 = "ln -s " . "\"$parentId.$shar$packExt\" " . " \"$name.$shar$packExt\"";
	my $cmd6 = "ln -s " . "\"$parentId.$uniq$packExt\" " . " \"$name.$uniq$packExt\"";

	if 	(
		  ( ( -f "$parentId.$orig" ) ||
		    ( -f "$parentId.$shar$packExt" ) ||
		    ( -f "$parentId.$uniq$packExt" )
		  )
		  &&
		  ( !   $overwrite )
		)
	{
		warn " "x4, "FILE $parentId.$orig EXISTS. NOT OVERWRITING";
		return 0;
	}

	print " "x4, "CMD1 :: AGGREGATE :: $cmd1 :: ";
	`$cmd1` if ($serious);
	my $cmd1Lines = "";
	my $measure   = "\n";
	if ($serious)
	{
		if ($pack)
		{
			$cmd1Lines = -s "$parentId.$orig";
			$cmd1Lines = 0 if ($cmd1Lines <= $minSize);
			$measure   = "BYTES";
		}
		else
		{
			$cmd1Lines = `wc -l $parentId.$orig | gawk '{print \$1}'`;
			$measure   = "LINES";
		}
	}
	chomp($cmd1Lines);
	print $cmd1Lines, " $measure\n";


	die "OUTPUT $parentId.$orig NOT FOUND" if (( ! -f "$parentId.$orig" ) && ( $serious ));
	my $size = -s "$parentId.$orig";
	die "ERROR. NO OUTPUT IN $parentId.$orig. SIZE = 0" if (( ! $size ) && ($serious));




	print " "x4, "CMD2 :: GREP :: $cmd2\n";
	`$cmd2` if ($serious);
	my $cmd2Lines = "";
	my $cmd3Lines = "";
	if ($serious)
	{
		$cmd2Lines = `wc -l $parentId.$shar | gawk '{print \$1}'`;
		$cmd3Lines = `wc -l $parentId.$uniq | gawk '{print \$1}'`;
	}
	chomp ($cmd2Lines);
	chomp ($cmd3Lines);
	print "\t$parentId.$shar :: ", $cmd2Lines, " $measure\n";
	print "\t$parentId.$uniq :: ", $cmd3Lines, " $measure\n";



	print " "x4, "CMD3 :: ZIP :: $cmd3\n";
	`$cmd3` if ($serious);

	if ((( ! -f "$parentId.$shar$packExt" ) || ( ! -f "$parentId.$uniq$packExt" )) && ($serious))
	{
		die "OUTPUT $parentId.$shar$packExt OR $parentId.$uniq$packExt NOT FOUND\n";
	}



	print " "x4, "CMD4 :: LINK ROOT :: $cmd4\n";
	`$cmd4` if ($serious);

	if ( $cmd2Lines )
	{
		print " "x4, "CMD5 :: LINK SHARED :: $cmd5\n";
		`$cmd5` if ($serious);
	}
	else
	{
		unlink("$parentId.$shar$packExt");
	}


	if ( $cmd3Lines )
	{
		print " "x4, "CMD6 :: LINK UNIQUE :: $cmd6\n";
		`$cmd6` if ($serious);
	}
	else
	{
		unlink("$parentId.$uniq$packExt");
	}


	print "\n";
}


sub getKidsFiles
{
	my $localKids = $_[0];
	my $parentId  = $_[1];
	my %kidHaveFile;
	
	#foreach kid list all three extensions (wc, shared and unique)
	for (my $kidId = (@$localKids - 1); $kidId >= 0; $kidId--)
	{
		my $kid = $localKids->[$kidId];
		print " "x4 , "KID: ", $taxNamesArray->[$kid] , "\n";

		my $filesWcHash = &getFiles($kid, "$normalExt$packExt");
		my $wcSize = 0;
		foreach my $file (keys %$filesWcHash)
		{
			print " "x6 , "FILE wc: ", $file , "\n";
			my $size = -s $file;
			#$wcSize += $size;
			if ($size > $minSize)
			{
				$kidHaveFile{wc}{$kid}{$file} = $size;
				$descendants{$parentId}{$kid} = 1;
			}
		}


		print " "x6 , "FILES wc: ";
		
		if ( ( exists $kidHaveFile{wc} ) && ( exists ${$kidHaveFile{wc}}{$kid}) )
		{ print scalar(keys %{$kidHaveFile{wc}{$kid}}); }
		else
		{ print "0"; }
		
		print " [" . $wcSize . " BYTES]\n";


		my $filesShHash = &getFiles($kid, "$shar$packExt");
		foreach my $file (keys %$filesShHash)
		{
			my $size = -s $file;
			print " "x6 , "FILES sh: ", $file , " [", $size, " BYTES]\n";
			
			if ($size > $minSize)
			{
				$kidHaveFile{sh}{$kid}{$file} = $size;

				if ( exists $descendants{$kid} )
				{
					foreach my $son ( keys %{$descendants{$kid}} )
					{
						$descendants{$parentId}{$son} = 1;
					}
				}
				else
				{
					$descendants{$parentId}{$kid} = 1;
				}
			}
		}
		
		
		my $filesUnHash = &getFiles($kid, "$uniq$packExt");
		foreach my $file (keys %$filesUnHash)
		{
			my $size = -s $file;
			print " "x6 , "FILES un: ", $file , " [", $size," BYTES]\n";
			
			if ($size > $minSize)
			{
				$kidHaveFile{sh}{$kid}{$file} = $size;
				
				if ( exists $descendants{$kid} )
				{
					foreach my $son ( keys %{$descendants{$kid}} )
					{
						$descendants{$parentId}{$son} = 1;
					}
				}
				else
				{
					$descendants{$parentId}{$kid} = 1;
				}
			}
		}
	} # end for my local kids
	return \%kidHaveFile;
}








sub mergeSpp
{
	#group variants of same species as one file containing their shared seqs
	my $filesWcHash = &getFiles("", $normalExt);
	my %outHash;
	foreach my $file (keys %$filesWcHash)
	{
		#print " "x6 , "FILE wc: ", $file , "\n";
		if ($file =~ /(\d+)\_(\d+)\_(\d+)/)
		{
			my $spp = $1;
			my $var = $2;
			my $chr = $3;
			$outHash{$spp}[$var]{$file} = -s $file;
		}
	}
	
	my $totalSpps = scalar (keys %outHash);
	my $sppCount  = 0;
	foreach my $spp (keys %outHash)
	{
		$sppCount++;
		my $vars = 0;
		map { $vars++ if (defined $_) } @{$outHash{$spp}};
		
		print 	"SPP [$sppCount/$totalSpps]", $taxNamesArray->[$spp] ,
				" IS COMPOSED BY ", $vars ," VARIETIES\n";
		
		for (my $var = 0; $var < @{$outHash{$spp}}; $var++ )
		{
			next if ( ! defined $outHash{$spp}[$var] );
			print 	"\tVARIETY ", $var, " CONTAINS ",
					scalar( keys %{$outHash{$spp}[$var]} )," FILES\n";
			
			my $cFile   = 0;
			my $sumFile = 0;
			foreach my $file ( keys %{$outHash{$spp}[$var]} )
			{
				print "\t\t",$file,"..." if ( ! $cFile++ );
				$sumFile += $outHash{$spp}[$var]{$file};
			}
			print " --> [",$sumFile," bytes]\n";
		}
		
		if ( ! -f "$spp.$normalExt$packExt" )
		{
			# agregator spp only exports sequences which shares all organisms
			# from the group.
			my $sppCmd = "cat $spp\_*.$normalExt | sort -k 1,8 | " .
						 "$agregatorSpp $vars $packCmdStdin > $spp.$normalExt.tmp";
						 
			print "\t\t\tSPPCMD: $sppCmd\n";
			`$sppCmd`;
			rename("$spp.$normalExt.tmp", "$spp.$normalExt$packExt");
		}
		
		print "\n\n";
	}
}



##############################################################################
################################## FUNCTIONS #################################
##############################################################################
sub getFiles
{
	my $prefix = $_[0] || "";
	my $sufix  = $_[1] || "";
	
	#print "\t\t\tGETTING FILE :: PREFIX: $prefix SUFIX: $sufix";
	
	opendir (DIR, "./") or die "FAILED TO OPEN DIR ./: $!";
	my @infiles;
	
	if ($prefix eq "")
	{
		@infiles = grep /\.$sufix$/, readdir(DIR);
	}
	else
	{
		@infiles = grep /^$prefix.*\.$sufix$/, readdir(DIR);
	}
	
	closedir DIR;
	my @insizes = sort { $a <=> $b } map {-s} @infiles;
	my %files;
	
	for (my $f = 0; $f < @infiles; $f++)
	{
		$files{$infiles[$f]} = $insizes[$f];
	}
	#print " RESULT: ", scalar(keys %files), "\n";
	return \%files;
}




sub printOutFile
{
	my $line      = $_[0];
	my $threadNum = $_[1];
	my $pDone     = $_[2];
	
	if (( ! ($totalLines % $splitSize) ) || ($totalLines == 0))
	{
		if (defined $fh )
		{
			close $fh;
			print "\t[$threadNum] CLOSING FH OF $currentFile\n";
		
			print "\t[$threadNum] PACKING FINISHED FILE $currentFile\n";
			`cat $currentFile | sort -k 1,8 | $agregator | gzip -c$compLevel > $currentFile.sort.ag.gz`;
			`rm -f $currentFile`;
			print "\t[$threadNum] FINISHED FILE $currentFile PACKED\n\n";
			$suffix++;
		}

		$currentFile = "$outDir$prefix\_$suffix.wc";		
		print "[$threadNum] OPENNING $currentFile [$totalOutput]\n";
		open ($fh, '>', "$currentFile") or die "COULD NOT OPEN $prefix\_$suffix.wc TO STORE: $!";

		print "[$threadNum] STARTING PRINTING TO $currentFile\n";
		print $fh $$line;

		$totalOutput++;
		$totalLines = 1;
		$totalLinesM++;
	}
	elsif ($pDone)
	{
		if (defined $fh )
		{
			close $fh;
			print "\t[$threadNum] CLOSING FH OF $currentFile\n";
		}

			print "\t[$threadNum] PACKING FINISHED FILE $currentFile\n";
			`cat $currentFile | sort -k 1,8 | $agregator | gzip -c$compLevel > $currentFile.sort.ag.gz`;
			`rm -f $currentFile`;
			print "\t[$threadNum] FINISHED FILE $currentFile PACKED\n\n";
	}
	else
	{
		$totalLines++;
		print $fh $$line;
	}
}




sub getTaxArray
{
	my $taxFile = $_[0];
	my @tax;
	my @names;
	my @levels;
	
	open TAX, "<$taxFile" or die "COULD NOT OPEN TAXONOMY.TAB: $!";
	while (my $line = <TAX>)
	{
		chomp $line;
		my ($level, $name, $kids) = split("\t", $line);
		
		if ($level =~ /\[(\d+)\]/)
		{
			$levels[$1] = $level;
			$level = $1;
		}
		
		if ($name =~ /\[(\d+)\]/)
		{
			$names[$1] = $name;
			$name = $1;
		}

		#printf "GLOBING LEVEL %02d NAME %06d KIDS %s\n", $level, $name , $kids;
		
		my @kids = split(",", $kids);
		
		for (my $k = 0; $k < @kids; $k++)
		{
			my $kid = $kids[$k];
			if ($kid =~ /\[(\d+)\]/)
			{
				$names[$1] = $kid;
				$kid = $1;
			}
			$kids[$k] = $kid;
		}
		
		$tax[$level][$name] = \@kids;
	}
	
	close TAX;
	
	
	#for (my $name = 0; $name <= @tax; $name++)
	#{
	#	next if ( ! defined $tax[$name] );
	#	print "ANALYZING $name [",$names[$name],"]\n";
	#	my $kids = $tax[$name];
	#	   $kids = &desintangleKids(\@tax, \@names, $kids, 0, $name);
	#}
	
	return \@tax, \@names, \@levels;
}















##############################################################################
#################################### TOOLS ###################################
##############################################################################

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

##############################################################################
#################################### TRASH ###################################
##############################################################################
#for (my $name = 0; $name <= @tax; $name++)
#{
#	next if ( ! defined $tax[$name] );
#	print "ANALYZING $name [",$names[$name],"]\n";
#	my $kids = $tax[$name];
#	   $kids = &desintangleKids($kids, 0, $name);
#	
#	$tax[$name] = $kids;
#	my $greps = "";
#	foreach my $kid (@{$kids})
#	{
#		print "\tRESULT\t", $kid, "[",$names[$kid],"]\n";
#		$greps .= " | grep $kid";
#	}
#	
#	my $cmd1  = "cat $indir/shared*";
#	my $cmd2  = " > $outdir/$name.wc";
#	my $cmd   = "$cmd1 $greps $cmd2";
#	my $lnCmd = "ln -s \"$outdir/$name.wc\" \"$outdir/" . $names[$name] . ".wc\"";
#	my $wcCmd = "wc -l $outdir/$name.wc | gawk '{print \$1}'";
#	print "\t\t$cmd\n";
#	print "\t\t$lnCmd\n";
#	print "\t\t$wcCmd\n";
#	`$cmd`;
#	`$lnCmd`;
#	my $lines = `$wcCmd`;
#	print "$lines LINES EXPORTED\n\n";
#}


sub desintangleKids
{
	my @tax    = @{$_[0]};
	my @names  = @{$_[1]};
	my $kids   =   $_[2];
	my $level  =   $_[3] || 0;
	my $father =   $_[4] || ".";
	
	my @kids;
	print "\t", "__"x$level, "DESINTANGLING FATHER $father LEVEL $level\t", join("\t", @{$kids}), "\n" if ( $verbose );
	
	foreach my $kid (@{$kids})
	{
		print "\t", "    ", "____"x$level, "FOREACH FATHER $father LEVEL $level KID $kid\n" if ( $verbose );
		
		if ( defined $tax[$kid] )
		{
			print "\t", "      ", "______"x$level, "FATHER $father LEVEL $level KID $kid HAS KIDS\n" if ( $verbose );

			my $gkid = &desintangleKids(\@tax, \@names, $tax[$kid], $level++, $kid);

			foreach my $grandkid (@{$gkid})
			{
				print "\t", "        ", "________"x$level, "FATHER $father LEVEL $level KID $kid GRANKID > $grandkid\n" if ( $verbose );
				push(@kids, $grandkid);
			}
		}
		else
		{
			print "\t", "      ", "______"x$level, "FATHER $father LEVEL $level KID $kid HAS NO KIDS\n" if ( $verbose );
			push(@kids, $kid)
		}
	}
	
	print "\t", "__"x$level, "FATHER $father LEVEL $level DESINTANGLED\t", join("\t", @kids), "\n" if ( $verbose );
	print "\n\n" if  (( ! $level ) && ( $verbose ));
	
	return \@kids;
}










#my $filesHash   = &getFiles();
#my $fileCluster = &splitFiles($filesHash);




#my $threadCount = 0;
#for (my $c = 0; $c < @{$fileCluster}; $c++)
#{
#	#&runFileHash($fileCluster->[$c], $threadCount++);
#	&newThread(\&runFileHash, $fileCluster->[$c], $threadCount++);
#}
#
#&waitThread();








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
		my $line;
		while ($line = <FILE>)
		{
			printOutFile(\$line, $threadNum);
		}
		close FILE;
		
		#printOutFile(\$line, $threadNum);
		
		print "\t\t[$threadNum] PACKING FILE $file TO $file.gz\n";
		`gzip -$compLevel $file`;
		
		print "\t\t[$threadNum] MOVING FILE $file.gz TO stock/$file.gz\n";
		move("$file.gz", "stock/$file.gz");
		
		$countFiles++;
	}

	printOutFile(undef, $threadNum, 1);
	
	print "\n\n[$threadNum] ",
	  ""      , ($totalLinesM * ($splitSize / 1_000_000)), " MILLONS",
	  " and " , $totalLines                , " LINES EXPORTED",
      " FROM ", $totalFiles                , " INPUT WC FILES",
	  " TO "  , $totalOutput               , " FILES",
	  " IN "  , (time - $sTime)            , "s\n";
}


sub getSuffix
{
	my $thread = $_[0];
	my @sufList;
	$sufList[0] = "aaa";
	$sufList[1] = "bbb";
	$sufList[2] = "ccc";
	$sufList[3] = "ddd";
	$sufList[4] = "eee";
	$sufList[5] = "fff";
	$sufList[6] = "ggg";
	$sufList[7] = "hhh";
	
	return $sufList[$thread];
}


1;
