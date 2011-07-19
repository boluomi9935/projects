#!/usr/bin/perl -w
use warnings;
use strict;

use Tie::Hash::Indexed;

#use BerkeleyDB;
#use DB_File ;
#use Array::Unique;
#use Tie::Array::Unique;

use threads;
use threads::shared;
use threads 'exit'=>'threads_only';

use lib "./filters";
use dnaPack;
use dnaCode;
use DBIconnect;

my $unique;
my %taxonomy;

`sudo renice -10 $$`;


my $inFile            = $ARGV[0];
my $taxonId           = $ARGV[1];
my $taxonVar          = $ARGV[2];


my $indirTaxonomyFile = "./input/taxonomy.idx";	#IN ADITION TO INDIR
my $indir             = "./input";
my $bdbFolder         = "./bdb";

my $binDir            = "./bin";
my $sqlDir            = "./sql";
my $txtDir            = "./txt";

my $napTime           = 10;
my $maxThreads        = 1;
my $seqLen            = 32;
my $schemaName        = 'probe2';
my $tableName         = 'probe2';
my $columnName        = 'probe';
my $maxAllowedPackage = 15_000;

my $mapReduce = 1;
my $byFile    = 1;
my $byHash    = 0;
my $byArray   = 0;

my $saveFile    = 1;
my $saveFileTxt = 1;
my $saveFileBin = 0;

my $saveSql  = 0;
my $saveDbh  = 0;

if ($mapReduce)  { $byFile = 1; $saveFile = 1; $saveFileTxt = 1;  $saveFileBin = 0; $byHash = 0; $byArray = 0; $saveSql = 0; $saveDbh = 0; };

if    ($byFile)  { $byHash = 0; $byArray = 0; print "! USING FILE  !\n"; }
elsif ($byArray) { $byHash = 0; $byFile  = 0; print "! USING ARRAY !\n"; }
elsif ($byHash)  { $byFile = 0; $byArray = 0; print "! USING HASH  !\n"; }
else             { die "PLEASE SELECT SORT METHOD" }

if ( ! $byFile )
{
	if    ($saveFile) { $saveSql  = 0; $saveDbh = 0; print "! SAVING FILE !\n"; }
	elsif ($saveSql)  { $saveFile = 0; $saveDbh = 0; print "! SAVING SQL  !\n"; }
	elsif ($saveDbh)  { $saveFile = 0; $saveSql = 0; print "! SAVING DBH  !\n"; }
	else              { die "PLEASE SELECT EXPORT METHOD" }
}
else
{
	print "SORTING BY FILE. NO EXPORT USED.\n";
}



my $dbh;

	







if ($inFile)
{
	my $sTime = time;
	if ( -f $inFile )
	{
		my $outFile = "$taxonId\_$taxonVar";
		
		$dbh  = &DBIconnect::DBIconnect() if ($saveDbh);	
		print "\tEXTRACTING FROM $inFile, $taxonId, $taxonVar\n";
		&mkHash($inFile, $taxonId, $taxonVar);
		print "\tEXTRACTION FROM $inFile, $taxonId, $taxonVar DONE IN ", (time - $sTime) ,"s\n";
		print "$inFile$taxonId$taxonVar", "SUCCESS\n";
	}
	else
	{
		die "FILE $inFile DOESNT EXISTS\n";
	}
	$dbh->commit() if ($saveDbh);
	$dbh->disconnect() if ($saveDbh);
}
else
{
	print "ITERATING OVER FILES AT $indir\n";

	opendir (DIR, "$indir") or die $!;
	my @infiles = grep /\.fasta$/, readdir(DIR);
	closedir DIR;
	
	my $outDir;
	my $ext;
	my %outFiles;
	
	if ($saveFile)
	{
		if ($saveFileTxt)
		{
			$outDir = $txtDir;
			$ext    = ".wc";
		}
		elsif ($saveFileBin)
		{
			$outDir = $binDir;
			$ext    = ".wb";
		}
	}
	elsif ($saveSql)
	{
		$outDir = $sqlDir;
		$ext    = ".I.sql";
	}
	
	if ($saveFile || $saveSql)
	{
		opendir (DIR, "$outDir") or die $!;
		#print "\tANALYZING $outDir FOR $ext:\n";
		my @outFiles = grep /$ext$/, readdir(DIR);
		closedir DIR;
		foreach my $file (@outFiles)
		{
			#print "\t\tCHECKING FILE: $file\n";
			if ($file =~ /(\d+)\_(\d+)/)
			{
				$outFiles{$1}{$2} = 1;
				#print "\t\t\tALREADY ON OUTDIR: $1 $2\n";
			}
		}
	}
	#$| = 1;

	
	if ( ! @infiles ) { die "NO FASTA FILES FOUND IN $indir DIRECTORY"};
	
	print "\n", scalar(@infiles), " FILES FOUND\n";
	
	&getTaxonomy($indirTaxonomyFile);
	
	my $neededIds = &getNeeded();

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
		next if (( scalar(keys %{$neededIds}) > 0 ) && ( ! exists $neededIds->{$id} ));

		while (threads->list(threads::running) > ($maxThreads-1))
		{
			sleep($napTime); 
		}

		foreach my $thr (threads->list(threads::joinable))
		{
			$thr->join();
		}

		threads->new(\&actuator, ($indir, $file, $fileCount++, $fileTotal));

	}
	
	&waitThread();
	print "ITERATING OVER FILES AT $indir COMPLETED\n";
}




sub getNeeded
{
	my $inFile   = "./needed.lst";
	my $skipFile = "./skip.lst";
	my %needed;
	my %skiped;

	if ( -f $skipFile )
	{
		open IN, "<$skipFile" or die "COULD NOT OPEN $skipFile: $!";
		while (my $id = <IN>)
		{
			chomp $id;
			$skiped{$id} = 1;
		}
		close IN;
	}
	
	if ( -f $inFile )
	{
		open IN, "<$inFile" or die "COULD NOT OPEN $inFile: $!";
		while (my $id = <IN>)
		{
			chomp $id;
			if ( exists $skiped{$id} )
			{
				print "SKIPPING $id. ALREADY IN THE SYSTEM.\n"
			}
			else
			{
				$needed{$id} = 1
			}
		}
		close IN;
	}
	else
	{
		print "NO FILE needed.lst. USING ALL FILES.\n";
	}
	
	return \%needed;
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

#############################################
######## FUNCTIONS
#############################################
sub mkHash
{
	my $inputFile         = $_[0];
	my $inputTaxonInfoId  = $_[1];
	my $inputTaxonInfoVar = $_[2];
	my $outName           = "$inputTaxonInfoId.$inputTaxonInfoVar";
	$| = 1;


	print "\tCRATING HASH FOR SEQUENCE $inputFile TO $outName:\n";
	
	#if ( -f "$outName.wc" )
	#{
	#	print "\t\tOUTPUT EXISTS, SKIPPING\n";
	#	return undef;
	#}
	
	$| = 0;
	my $fastaHash = &getFasta($inputFile);
	$| = 1;

	my $count     = 1;
	my $total     = scalar keys %{$fastaHash};

	my %wcHash;
	my @wcArray;
	#tie @wcArray, "Array::Unique";
	#tie @wcArray, 'Tie::Array::Unique';

	
	my $tied   = 0;
	my $dbH;
	my $fileSize = -s $inputFile;
	print "\t\tFILESIZE: $fileSize\n";

	#if( ($fileSize) > (70 * (1024*1024)) )
	if(0)
	{
		my $filenameH = "$bdbFolder/WordListH_$inputTaxonInfoId.$inputTaxonInfoVar.db";
	
		print "\t\tFILE IS TOO BIG. TIEING TO FILE: $filenameH\n";
	
		`rm -f $filenameH 2>/dev/null`;
		unlink($filenameH);
	
		$dbH = new DB_File::HASHINFO;
		#tie %wcHash, "DB_File", $filenameH, O_RDWR|O_CREAT, 0666, $dbH or die "Cannot open $filenameH: $!\n";
		$tied = 1;
	}

	while ((my $chrom, my $countF) = each (%{$fastaHash}))
	{
		print "\t\tCREATING FRAGMENT TO $chrom [",$count,"/",$total,"]...\n";
		&mkFragments(\$fastaHash->{$chrom},  \%wcHash, \@wcArray, $tied);
		$count++;
	}

	&saveWcHash( $outName, $count, \%wcHash)  if $byHash;
	&saveWcArray($outName, $count, \@wcArray) if $byArray;
	#&wd2wc($taxonId, $taxonVar) if $byFile;
	

	if ($saveFile && $saveFileTxt && $mapReduce)
	{
		if ( -f "$txtDir/$taxonId\_$taxonVar.wd")
		{
			rename("$txtDir/$taxonId\_$taxonVar.wd", "$txtDir/$taxonId\_$taxonVar.wc");
		}
	}
	if ( ! ($saveFile && $saveFileTxt) )
	{
		&wd2wb($taxonId, $taxonVar) if $byFile;
	}
	elsif ($saveFile && $saveFileTxt)
	{
		&wd2wc($taxonId, $taxonVar) if $byFile;
	}

	
	%wcHash = ();
	@wcArray = ();
	
	print "\tHASH COMPLETE\n";
	$| = 0;
	#&saveWc($outName, \%wcHash);
	
	if ($tied)
	{
		undef $dbH;
		untie %wcHash;
	}
}


sub wd2wb
{
	my $taxonId  = $_[0];
	my $taxonVar = $_[1];
	print "\t\t\t\t\tFUNCTION wd2wb\n";
	&wd2wc($taxonId, $taxonVar);
	my $fileInName = "$binDir/$taxonId\_$taxonVar.wc";
	my $fileOuName = "$txtDir$taxonId\_$taxonVar.wb";
	
	open IN, "<$fileInName" or die "COULD NOT OPEN $fileInName: $!";
	open OU, ">$fileOuName" or die "COULD NOT OPEN $fileOuName: $!";
	
	binmode OU;
	
	while (my $frag = <IN>)
	{
		chomp $frag;
		$frag = &dnaPack::packDNA($frag);
		print OU $frag;
	}
	
	close OU;
	close IN;
	
	my $sizeIn = -s $fileInName;
	my $sizeOu = -s $fileOuName;
	
	my $diff = $sizeIn - $sizeOu;
	my $prop = sprintf("%.2f", ($sizeOu / $sizeIn));
	
	if (($diff) && ($diff > 1))
	{
		print "\tASCII: ", &byte2Mb($sizeIn)," BINARY: ", &byte2Mb($sizeOu), " DIFF: $diff PROP: $prop\n";
		unlink($fileInName);
	}
	else
	{
		die "NO DIFF";
	}
}

sub wd2wc
{
	my $taxonId  = $_[0];
	my $taxonVar = $_[1];
	print "\t\t\t\t\tFUNCTION wd2wc\n";
	my $fileInName = "$txtDir/$taxonId\_$taxonVar.wd";
	my $fileOuName = "$txtDir/$taxonId\_$taxonVar.wc";
	
	return undef if ( ! -f $fileInName );
	
	print "\tEXECUTING SORT... ";
	open(SORT, "sort -u -o $fileOuName $fileInName 2>&1|") or die "FAILED TO EXECUTE FIRST: $!";
	while ( my $line = <SORT> )
	{
		die if $line;
	}
	close SORT;
	print "done\n";

	print "\tCOUNTING LINES... ";
	my $wcIn;
	open(WCIN, "wc -l $fileInName 2>&1|") or die "FAILED TO EXECUTE FIRST: $!";
	while ( my $line = <WCIN> )
	{
		if ($line =~ /(\d+)\s+$fileInName/)
		{
			$wcIn = $1;
		}
		else { die "ERROR ASSESSING OUTPUT SIZE"}
	}
	close WCIN;

	my $wcOut;
	open(WCOUT, "wc -l $fileOuName 2>&1|") or die "FAILED TO EXECUTE FIRST: $!";
	while ( my $line = <WCOUT> )
	{
		if ($line =~ /(\d+)\s+$fileOuName/)
		{
			$wcOut = $1;
		}
		else { die "ERROR ASSESSING OUTPUT SIZE" };
	}
	close WCOUT;
	print "done\n";
	
	my $diff = $wcIn - $wcOut;
	my $prop = sprintf("%.2f", ($wcOut / $wcIn));
	
	if (($diff) && ($diff > 1))
	{
		print "\tORIGINAL: $wcIn UNIQUE: $wcOut DIFF: $diff PROP: $prop\n";
		unlink($fileInName);
	}
	else
	{
		die "NO DIFF";
	}

}


sub mkFragments
{
	print "\t\t\t\t\tFUNCTION mkfragments\n";
	&mkFragmentsHash( $_[0], $_[1], $_[3]) if $byHash;
	&mkFragmentsArray($_[0], $_[2], $_[3]) if $byArray;
	&mkFragmentsFile( $_[0], $_[3], $_[3]) if $byFile;
}

sub mkFragmentsFile
{
	my $sequence   = $_[0];
	my $wcHash     = $_[1];
	my $tied       = $_[2];
	my $revC       = 0;
	print "\t\t\t\t\tFUNCTION mkfragmentsfile\n";
	my $sequenceLength = length($$sequence);
	my $lastLigStart   = $sequenceLength - $seqLen;

	print "\t\t\tFRAGMENTING $sequenceLength BP SEQ... ";

	my $outFile  = "$txtDir/$taxonId\_$taxonVar.wc";
	my $outFileT = $outFile;
	$outFileT =~ s/\.wc$/\.wd/;
	
	if ( -f $outFile ) { unlink($outFile); unlink($outFileT); };
	$outFile = $outFileT;

	open WD, ">>$outFile" or die "COULD NOT OPEN WB FILE $outFile: $!";
	
	my $prefix = '';
	if ($mapReduce) { $prefix = "\t$taxonId\_$taxonVar" };

	my $frag;
	#for my $MKFsequence ($sequence, $sequence)
	for my $MKFsequence ($sequence)
	{
		if ( $revC ) 
		{
			print "REV... ";
			$$MKFsequence = reverse($$MKFsequence);  
			$$MKFsequence =~ tr/ACGT/TGCA/; 
		}
		else 
		{ 
			print "FWD... ";
			$revC++;
		};
		
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

			$frag = &dnaCode::dna2digit($frag) if ($mapReduce);

			print WD $frag, $prefix, "\n";
			
			$ligStart++;
			$frag = "";
		} # END FOR MY $LIGSTART
	}
	
	close WD;
	
	print "DONE\n";

}



sub mkFragmentsHash
{
	my $sequence   = $_[0];
	my $wcHash     = $_[1];
	my $tied       = $_[2];
	my $revC       = 0;
	print "\t\t\t\t\tFUNCTION mkfragmentshash\n";
	my $sequenceLength = length($$sequence);
	my $lastLigStart   = $sequenceLength - $seqLen;

	print "\t\t\tFRAGMENTING $sequenceLength BP SEQ... ";

	my $frag;
	#for my $MKFsequence ($sequence, $sequence)
	for my $MKFsequence ($sequence)
	{
		if ( $revC ) 
		{
			print "REV... ";
			$$MKFsequence = reverse($$MKFsequence);  
			$$MKFsequence =~ tr/ACGT/TGCA/; 
		}
		else 
		{ 
			print "FWD... ";
			$revC++;
		};
		
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
			
			#$frag = &dnaCode::dna2digit($frag);
			if ( ! ($saveFile && $saveFileTxt) )
			{
				$frag = &dnaPack::packDNA($frag);
			}
			#my $frag0 = &dnaPack::packDNA($frag);
			#my $frag1 = &dnaPack::unPackDNA($frag0, $seqLen);
			#print "FRAG $frag ",(length($frag))," FRAG0 $frag0 ",(length($frag0))," FRAG1 $frag1 ",(length($frag1))," \n";

			if ( ! $tied )
			{
				#$unique++ if ( ! exists $wcHash->{$frag} );
				$wcHash->{$frag}++;
			}
			else
			{
				$wcHash->{$frag} = 1;
			}
			$unique++;
			$ligStart++;
			$frag = "";
		} # END FOR MY $LIGSTART
	}
	
	print "DONE: $unique FRAGMENTS ADDED\n";
}


sub mkFragmentsArray
{
	my $sequence   = $_[0];
	my $wcArray    = $_[1];
	my $tied       = $_[2];
	my $revC       = 0;
	print "\t\t\t\t\tFUNCTION mkfragmentsarray\n";
	my $sequenceLength = length($$sequence);
	my $lastLigStart   = $sequenceLength - $seqLen;

	print "\t\t\tFRAGMENTING $sequenceLength BP SEQ... ";

	my $frag;
	#for my $MKFsequence ($sequence, $sequence)
	for my $MKFsequence ($sequence)
	{
		if ( $revC ) 
		{
			print "REV... ";
			$$MKFsequence = reverse($$MKFsequence);  
			$$MKFsequence =~ tr/ACGT/TGCA/; 
		}
		else 
		{ 
			print "FWD... ";
			$revC++;
		};
		
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
			
			#$frag = &dnaCode::dna2digit($frag);
			
			if ( ! ($saveFile && $saveFileTxt) )
			{
				$frag = &dnaPack::packDNA($frag);
			}
			#my $frag0 = &dnaPack::packDNA($frag);
			#my $frag1 = &dnaPack::unPackDNA($frag0, $seqLen);
			#print "FRAG $frag ",(length($frag))," FRAG0 $frag0 ",(length($frag0))," FRAG1 $frag1 ",(length($frag1))," \n";

			push(@{$wcArray}, $frag);

			$ligStart++;
			$frag = "";
		} # END FOR MY $LIGSTART
	}
	
	print "DONE\n";

}


sub saveWcHash
{
	my $inputTaxonId = $_[0];
	my $chromCount   = $_[1];
	my $wcHash       = $_[2];
	print "\t\t\t\t\tFUNCTION savewchash\n";
	$inputTaxonId =~ s/\./\_/;

	my $totalK = scalar keys %{$wcHash};
	my $pieces = 1;
	if ($totalK >= $maxAllowedPackage)
	{
		$pieces = int($totalK / $maxAllowedPackage) + 1;
	}
	
	my $start = 0;
	my $end   = $totalK - 1;
	my @words;
	
	if ($saveSql || $saveDbh)
	{
	   $end   = $maxAllowedPackage;
	   @words = keys %{$wcHash};
	}
	else
	{
		$pieces            = 1;
		$maxAllowedPackage = $totalK;
	}
	   
	if ($end > $totalK) { $end = $totalK-1 };
	print "\t\t\t\tSAVING WORD COUNT. $totalK WORDS FOUND...\n";
	my $inTime = time;
	
	my $commandInsert;
	my $commandUpdate;
	my @slice;
	
	for (my $part = 0; $part < $pieces; $part++)
	{
		my $sTime = time;
		$start = $part  * $maxAllowedPackage;
		$end   = $start + $maxAllowedPackage - 1;
		if ($end > $totalK) { $end = $totalK - 1 };
		printf "\t\t\t\t\tSAVING PART %03d / %03d STARTING AT %012d UNTIL %012d...\n", $part, $pieces, $start, $end;

		if ($saveSql || $saveDbh)
		{
			@slice = @words[$start .. $end];
			&saveOut($inputTaxonId, $chromCount, \@slice, $pieces, "array");
		}
		else
		{
			&saveOut($inputTaxonId, $chromCount, $wcHash, $pieces, "hash");
		}
		
		@slice = ();
		printf "\t\t\t\t\tSAVING PART %03d / %03d STARTING AT %012d UNTIL %012d COMPLETED IN %04d s\n\n", $part, $pieces, $start, $end, (time - $sTime);
	}
	
	print "\t\t\t\tSAVING WORD COUNT COMPLETED IN (",(time - $inTime),"s)...\n";
}


sub saveWcArray
{
	my $inputTaxonId = $_[0];
	my $chromCount   = $_[1];
	my $wcArray      = $_[2];
	print "\t\t\t\t\tFUNCTION savewcarray\n";
	$inputTaxonId =~ s/\./\_/;

	my $totalK = scalar @{$wcArray};
	my $pieces = 1;
	if ($totalK >= $maxAllowedPackage)
	{
		$pieces = int($totalK / $maxAllowedPackage) + 1;
	}
	
	my $start = 0;
	my $end   = $totalK - 1;
	if ($saveSql || $saveDbh)
	{
	   $end   = $maxAllowedPackage;
	}
	else
	{
		$pieces            = 1;
		$maxAllowedPackage = $totalK;
	}
	   
	if ($end > $totalK) { $end = $totalK-1 };
	print "\t\t\t\tSAVING WORD COUNT. $totalK WORDS FOUND...\n";
	my $inTime = time;

	my $commandInsert;
	my $commandUpdate;
	my @slice;
	
	for (my $part = 0; $part < $pieces; $part++)
	{
		my $sTime = time;
		$start = $part  * $maxAllowedPackage;
		$end   = $start + $maxAllowedPackage - 1;
		if ($end > $totalK) { $end = $totalK - 1 };
		printf "\t\t\t\t\tSAVING PART %03d / %03d STARTING AT %012d UNTIL %012d...\n", $part, $pieces, $start, $end;
		
		if ($saveSql || $saveDbh)
		{
			@slice = $wcArray->[$start .. $end];
			&saveOut($inputTaxonId, $chromCount, \@slice, $pieces, "array");
		}
		else
		{
			&saveOut($inputTaxonId, $chromCount, $wcArray, $pieces, "array");
		}
		
		@slice = ();
		printf "\t\t\t\t\tSAVING PART %03d / %03d STARTING AT %012d UNTIL %012d COMPLETED IN %04d s\n\n", $part, $pieces, $start, $end, (time - $sTime);
	}
	
	print "\t\t\t\tSAVING WORD COUNT COMPLETED IN (",(time - $inTime),"s)...\n";
}

sub saveOut
{
	my $inputTaxonId = $_[0];
	my $chromCount   = $_[1];
	my $slice        = $_[2];
	my $pieces       = $_[3];
	my $varType      = $_[4];
	print "\t\t\t\t\tFUNCTION saveout\n";
	&saveFil($inputTaxonId, $chromCount, $slice, $pieces, $varType) if ($saveFile);
	&saveSql($inputTaxonId, $chromCount, $slice, $pieces, $varType) if ($saveSql);
	&saveDbh($inputTaxonId, $chromCount, $slice, $pieces, $varType) if ($saveDbh);	
}


sub saveSql
{
	my $inputTaxonId = $_[0];
	my $chromCount   = $_[1];
	my $array        = $_[2];
	my $pieces       = $_[3];
	my $varType      = $_[4];
	print "\t\t\t\t\tFUNCTION savesql\n";
	my $chromCountT = "";
	if ($pieces > 1) { $chromCountT = "_$chromCount"; };
	
	my $stime        = time;
	my $fileI        = "$sqlDir/$inputTaxonId$chromCountT.I.sql";
	my $fileU        = "$sqlDir/$inputTaxonId$chromCountT.U.sql";
	print "\t\t\t\t\t\tSAVING SQL $fileI...";

	my $commandInsert      = "INSERT INTO `$schemaName`.`$tableName` ($columnName) VALUES ";
	my $commandUpdate      = "UPDATE `$schemaName`.`$tableName` SET $inputTaxonId = 1 WHERE $columnName = ?";

	open OUTU, ">>$fileU" or die "COULD NOT OPEN SQL FILE: $!";
	open OUTI, ">>$fileI" or die "COULD NOT OPEN SQL FILE: $!";
		
	if ( $varType eq "array" )
	{	
		foreach my $probe (@{$array})
		{
			$commandInsert .= "($probe),";
			$commandUpdate  =~ s/\?/$probe/;
			print OUTU $commandUpdate, ";\n";
		}
		chop $commandInsert;

		print OUTI $commandInsert, ";\n";
	}
	elsif ( $varType eq "hash" )
	{
		while ((my $probe, my $count) = each (%{$array}))
		{
			$commandInsert .= "($probe),";
			$commandUpdate  =~ s/\?/$probe/;
			print OUTU $commandUpdate, ";\n";
		}
		chop $commandInsert;

		print OUTI $commandInsert, ";\n";
	}
	
	close OUTI;	
	close OUTU;
	print "DONE(",(time - $stime),")\n";
}


sub saveFil
{
	my $inputTaxonId = $_[0];
	my $chromCount   = $_[1];
	my $array        = $_[2];
	my $pieces       = $_[3];
	my $varType      = $_[4];
	print "\t\t\t\t\tFUNCTION savefil\n";
	my $chromCountT = "";
	if ($pieces > 1) { $chromCountT = "_$chromCount"; };
	
	my $ext;
	if ($saveFileTxt)
	{
		$ext = "wc";
	}
	elsif ($saveFileBin)
	{
		$ext = "wb";
	}
	
	my $fileI        = "$binDir/$inputTaxonId$chromCountT.$ext";
	my $stime        = time;
	print "\t\t\t\t\t\tSAVING FILE $fileI...";

	open OUT, ">>$fileI" or die "COULD NOT OPEN SQL FILE: $!";
	binmode OUT;

	my $prefix = '';
	if ($mapReduce) {$prefix = "\t$inputTaxonId\n" }; #v3
	#if ($mapReduce) {$prefix = "$inputTaxonId," }; #v2
	

	if ( $varType eq "array" )
	{
		foreach my $probe (@{$array})
		{
			print OUT $probe, $prefix, "\n"; #v3
			#print OUT $prefix, $probe, "\n"; #v2
		}
	}
	elsif ( $varType eq "hash" )
	{
		while ((my $probe, my $count) = each (%{$array}))
		{
			print OUT $probe, $prefix; #v3
			#print OUT $prefix, $probe, "\n"; #v2
		}
	}

	close OUT;	
	print "DONE(",(time - $stime),")\n";
}


sub saveDbh
{
	my $inputTaxonId = $_[0];
	my $chromCount   = $_[1];
	my $array        = $_[2];
	my $pieces       = $_[3];
	my $varType      = $_[4];
	print "\t\t\t\t\tFUNCTION savedbh\n";
	my $stime        = time;
	print "\t\t\t\t\tSAVING SQL DBH...";

	my $commandInsert      = "INSERT IGNORE INTO `$schemaName`.`$tableName` ($columnName) VALUES " . "(?),"x(scalar @{$array} - 1) . "(?)";
	my $commandUpdate      = "UPDATE `$schemaName`.`$tableName` SET $inputTaxonId = 1 WHERE $columnName = ?";
	
	my $updateFh = $dbh->prepare_cached($commandUpdate);

	my $insertFh = $dbh->prepare_cached($commandInsert);
	if ( $varType eq "array" )
	{
		$insertFh->execute(@{$array}) or die "COULD NOT EXECUTE $commandUpdate : $! : $DBI::errstr";
		$insertFh->finish();
		foreach my $probe (@{$array})
		{
			$updateFh->execute($probe) or die "COULD NOT EXECUTE $commandUpdate : $! : $DBI::errstr";
		}
		$updateFh->finish();
	}
	elsif ( $varType eq "hash" )
	{
		$insertFh->execute(keys %{$array}) or die "COULD NOT EXECUTE $commandUpdate : $! : $DBI::errstr";
		while ((my $probe, my $count) = each (%{$array}))
		{
			$updateFh->execute($probe) or die "COULD NOT EXECUTE $commandUpdate : $! : $DBI::errstr";
		}
		$updateFh->finish();
	}

	$dbh->commit();
	print "DONE(",(time - $stime),")\n";
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




sub getFasta
{
	my $file    = $_[0];
	my $seqHash;
	my @seq;
	my @tmpSeq;
	my $count = 0;
	my $ID;
	my $sequence;
	my $progTotalBp = 0;
	print "\t\t\t\t\tFUNCTION getfasta\n";
	print "\t\tREADING FASTA FILE $file...";
	
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
					$seqHash->{$ID} = $sequence;
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
	$seqHash->{$ID} = $sequence;

	close FILE;
	print "DONE\n";
	print "\t\t\t$progTotalBp BP READED IN ",scalar keys %{$seqHash}," SEQS\n";
	return $seqHash;
}


sub byte2Mb
{
    my $in = $_[0];
    my $mb = (($in / 1024) / 1024);
    return sprintf("%.1f",$mb);
}

1;
