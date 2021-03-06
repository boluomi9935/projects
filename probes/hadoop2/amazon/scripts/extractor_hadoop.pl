#!/usr/bin/perl -w
use warnings;
use strict;

use threads;
use threads::shared;
#use threads 'exit'=>'threads_only';

#TODO
#MULTITHREAD CHROMOSSOMES
#SPLIT OUTPUT EACH 1M LINES

use lib "./filters";
use dnaCodeOO;
my %taxonomy;

my $inFile            = $ARGV[0];
my $taxonId           = $ARGV[1];
my $taxonVar          = $ARGV[2];

my $indirTaxonomyFile = "./input/taxonomy.idx";	#IN ADITION TO INDIR
my $indir             = "./input";
my $txtDir            = "./wc";

my $napTime           = 10;
my $maxThreads        = 4;
my $seqLen            = 32;

my $mapReduce         = 1;
my $byFile            = 1;
my $saveFile          = 1;
my $force             = 0; # force re-do despite of .wc file exists
my $pack              = 0;
my $split             = 0; # split over in 

my $ext               = ".wc";

#if ($pack) { $finalExt = ".wc.gz"};

my $dnaCode;

if ($inFile)
{
	my $sTime = time;
	if ( -f $inFile )
	{
		my $outFile = "$taxonId\_$taxonVar";
		
		print "\tEXTRACTING FROM $inFile, $taxonId, $taxonVar\n";
		&mkHash($inFile, $taxonId, $taxonVar);
		print "\tEXTRACTION FROM $inFile, $taxonId, $taxonVar DONE IN ", (time - $sTime) ,"s\n";
		print "$inFile$taxonId$taxonVar", "SUCCESS\n";
	}
	else
	{
		die "FILE $inFile DOESNT EXISTS\n";
	}
}
else
{
	print "ITERATING OVER FILES AT $indir\n";

	opendir (DIR, "$indir") or die "FAILED TO OPEN DIR $indir: $!";
	my @infiles = grep /\.fasta$/, readdir(DIR);
	closedir DIR;
	
	my $outDir;

	my %outFiles;
	
	$outDir = $txtDir;
	
	opendir (DIR, "$outDir") or die "FAILED TO OPEN OUTDIR $outDir: $!";
	#print "\tANALYZING $outDir FOR $ext:\n";
	my @outFiles = grep /\.done$/, readdir(DIR);
	closedir DIR;
	foreach my $file (@outFiles)
	{
		#print "\t\tCHECKING FILE: $file\n";
		if ($file =~ /^(\d+)\_(\d+)/)
		{
			$outFiles{$1}{$2} = 1;
			#print "\t\t\tALREADY ON OUTDIR: $1 $2\n";
		}
	}

	#opendir (DIR, "$outDir") or die "FAILED TO OPEN OUTDIR $outDir: $!";
	#@outFiles = grep /$packExt$/, readdir(DIR);
	#closedir DIR;
	#foreach my $file (@outFiles)
	#{
	#	#print "\t\tCHECKING FILE: $file\n";
	#	if ($file =~ /^(\d+)\_(\d+)/)
	#	{
	#		$outFiles{$1}{$2} = 1;
	#		#print "\t\t\tALREADY ON OUTDIR: $1 $2\n";
	#	}
	#}

	
	if ( ! @infiles ) { die "NO FASTA FILES FOUND IN $indir DIRECTORY"};
	
	print "\n", scalar(@infiles), " FILES FOUND\n";
	
	&getTaxonomy($indirTaxonomyFile);

	my $fileCount = 1;
	my $fileTotal = scalar(@infiles);

	foreach my $file (@infiles)
	{
		if ( exists $outFiles{$taxonomy{$file}[0]}{$taxonomy{$file}[1]} )
		{
			print "\tSKIPPING $file (",$taxonomy{$file}[0],".",$taxonomy{$file}[1],"). EXISTS.\n\n\n";
			next;
		}
		else
		{
			print "$file (",$taxonomy{$file}[0],".",$taxonomy{$file}[1],") DOESNT EXISTS. ANALYZING.\n";
		}
		
		my $id = "$taxonomy{$file}[0]\_$taxonomy{$file}[1]";

		&newThread(\&actuator, $indir, $file, $fileCount++, $fileTotal);
	}
	
	&waitThread();
	print "ITERATING OVER FILES AT $indir COMPLETED\n";
}


sub actuator
{
		my $indir     = $_[0];
		my $file      = $_[1];
		my $fileCount = $_[2];
		my $fileTotal = $_[3];
		my $sTime     = time;
		
		print "EXTRACTING WC FROM $file [",$fileCount,"/",$fileTotal,"]\n";

		my $id = $taxonomy{$file}[0] . "_" . $taxonomy{$file}[1];

		open(ACTUATOR, "./$0 $indir/$file " . $taxonomy{$file}[0] . " " . $taxonomy{$file}[1] . " 2>&1|") or die "FAILED TO EXECUTE FIRST: $!";
		my $success = 0;
		my $sucKey  = "$indir/$file" . $taxonomy{$file}[0] . $taxonomy{$file}[1] . "SUCCESS";
		
		while ( my $line = <ACTUATOR> )
		{
			print $line;
			$success = 1 if ($line =~ /$sucKey/);
		}
		close ACTUATOR;
		
		if ($success)
		{
			print "COMPLETED CORRECTLY\n";
			open  SK, ">>./skip.lst" or die "COULD NOT OPEN ./skip.lst: $!";
			print SK $id, "\n";
			close SK;
		}
		else
		{
			die "FAILED TO COMPLETE\n";
		}
		
		#&mkHash("$indir/$file", $taxonomy{$file}[0], $taxonomy{$file}[1]);
		print "EXTRACTION OF WC FROM $file COMPLETED IN: ",(time - $sTime),"s\n\n\n";
}


#############################################
######## FUNCTIONS
#############################################
sub mkHash
{
	my $inputFile         = $_[0];
	my $inputTaxonInfoId  = $_[1];
	my $inputTaxonInfoVar = $_[2];
	my $outName           = "$txtDir/$inputTaxonInfoId\_$inputTaxonInfoVar";

	print "\tCRATING HASH FOR SEQUENCE $inputFile TO $outName.wc:\n";
	
	if (( -f "$outName.done" ) && ( ! $force ))
	{
		print "\t\tOUTPUT EXISTS, SKIPPING\n";
		return undef;
	}

	my $fileSize = -s $inputFile;
	print "\t\tFILESIZE: $fileSize\n";

	$dnaCode = dnaCodeOO->new();	
	&getFasta($inputFile, $outName);
		
	open F, ">$outName.done" or die "COULD NOT CREATE $outName.done";
	print F '';
	close F;
	
	print "\tHASH COMPLETED\n";
}


sub mkFragments
{
	my $inFile     = $_[0];
	my $outName    = $_[1];
	my $ID         = $_[2];
	my $sequence   = $_[3];
	
	print "\t\t\t\t\tFUNCTION mkfragmentsfile $inFile $outName\n";
	my $sequenceLength = length($$sequence);
	my $lastLigStart   = $sequenceLength - $seqLen;

	print "\t\t\tFRAGMENTING $inFile :: $ID :: $sequenceLength BP SEQ TO $outName$ext ...\n";

	my $outFile  = "$outName$ext";
	my $outFileT = $outFile;
	$outFileT =~ s/$ext$/\.wd/;
	
	if ( -f $outFile ) { unlink($outFile); unlink($outFileT); };
	$outFile = $outFileT;

	open WD, ">$outFile" or die "COULD NOT OPEN WB FILE $outFile: $!";
	
	my $prefix = "\t$taxonId\_$taxonVar";

	my $frag;
	for my $MKFsequence ($sequence)
	{
		my $ligStart = 0;

		while ($ligStart < $lastLigStart)
		{
			$frag = substr($$MKFsequence, $ligStart, $seqLen);
			#print "\t\t\t$frag\n";
			if ( $frag =~ /N/)
			{
				$ligStart++;
				next;
			}

			$frag = $dnaCode->dna2digit($frag);

			print WD "$frag$prefix\n";
			
			$ligStart++;
			$frag = "";
		} # END FOR MY $LIGSTART
	}
	
	close WD;

	if ( -f "$outName.wd")
	{
		rename("$outName.wd", "$outName$ext");
	}
	else
	{
		die "FAILED CREATING TEMP FILE $outName.wd";
	}

	print "\t\t\tFRAGMENTING $inFile :: $ID :: $sequenceLength BP SEQ TO $outName$ext ... DONE\n";
}



sub getFasta
{
	my $file    = $_[0];
	my $outFile = $_[1];
	
	my @seq;
	my @tmpSeq;
	my $ID;
	my $sequence;
	my $progTotalBp = 0;
	my $count       = 0;
	my $countChrom  = 0;
	
	print "\t\t\t\t\tFUNCTION getfasta\n";
	print "\t\tREADING FASTA FILE \"$file\"...\n";
	
	open FILE, "<$file" or die "COULD NOT OPEN FASTA FILE $file: $!\n";
	while (my $line = <FILE>)
	{
		chomp $line;
		$count++;
		if ($line)
		{
			if (substr($line,0,1) eq '>')
			{
				if ((defined $ID) && ($sequence))
				{
					$progTotalBp += length($sequence);

					my $outName = $outFile . "_" . sprintf("%04d", $countChrom);

					if ( -f "$outName.wd" )
					{
						unlink("$outName.wd")
					}
					
					if (( -f "$outName$ext" ) && ( $force ))
					{
						unlink("$outName$ext");
						&mkFragments($file, $outName, $ID, \$sequence);
					}
					elsif ( -f "$outName$ext" )
					{
						print "\t\t\tfile $outName$ext exists. skipping. please delete it or enable force\n";
					}
					else
					{
						&mkFragments($file, $outName, $ID, \$sequence);
					}

					$countChrom++;
				}

				$ID     = substr($line, 1);
				$line   = substr($line, 1);

				#if ($ID =~ /(\S+)\s/) {$ID = $1;};
				$ID =~ tr/ /_/;
				$ID =~ tr/\//_/;
				$ID =~ tr/a-zA-Z0-9_/_/cd;

				$sequence = "";
			} # end if ^>
			else
			{
				$line = uc($line);
				$line =~ tr/[A|C|T|G|N]/N/cd;
				if ($line =~ /[^ACTGN]/){ die "STRANGE CHARACTER IN FASTA: $line";};
				
				if ((defined $ID) && ($ID ne "") && ($ID ne " "))
				{
					$sequence .= $line;
				}
				else
				{
					
				}
			} # end if else ^>
		} #end if $_
	} # end while file

	$progTotalBp += length($sequence);
	
	my $outName = $outFile . "_" . sprintf("%04d", $countChrom);

	if ( -f "$outName.wd" )
	{
		unlink("$outName.wd")
	}
	
	if (( -f "$outName$ext" ) && ( $force ))
	{
		unlink("$outName$ext");
		&mkFragments($file, $outName, $ID, \$sequence);
	}
	elsif ( -f "$outName$ext" )
	{
		print "file exists. skipping. please delete it or enable force";
	}
	else
	{
		&mkFragments($file, $outName, $ID, \$sequence);
	}

	close FILE;
	print "DONE\n";
	print "\t\t\t$progTotalBp BP READED IN $countChrom SEQS\n";
}


sub byte2Mb
{
    my $in = $_[0];
    my $mb = (($in / 1024) / 1024);
    return sprintf("%.1f",$mb);
}



sub getTaxonomy
{
	my $file = $_[0];
	print "LOADING TAXONOMIC FILE $file...";
	print "\t\t\t\t\tFUNCTION gettaxonomy\n";
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
	print "\t$countValid FILES IN TAXONOMIC INDEX\n\n";
}




sub revComp($)
{
	my $sequence = uc($_[0]);
	my $rev = reverse($sequence);
	$rev =~ tr/ACTG/TGAC/;
	return $rev;
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
