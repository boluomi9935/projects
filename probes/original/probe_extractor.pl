#!/usr/bin/perl -w
# Saulo Aflitos
# 2009 06 18 19 47
use strict;
use Storable;
use Data::Dumper;
use filters::loadconf;
my %pref = &loadconf::loadConf;
#$pref{""}

#############################################
######## SETUP
#############################################
&loadconf::checkNeeds("log","maxThreads","resetAtStart","napTime","outDir","dumpDir","sqlDir");

my $log          = $pref{"log"}; #HOW VERBOSY 
my $maxThreads   = $pref{"maxThreads"};	
my $resetAtStart = $pref{"resetAtStart"};
my $napTime      = $pref{"napTime"};
my $outDir       = $pref{"outDir"};
my $dumpDir      = $pref{"dumpDir"};
my $sqlDir       = $pref{"sqlDir"};



#############################################
######## USAGE DECLARATIONS
#############################################
#`sudo renice -10 $$`;
use List::Util qw[min max];
use threads;
use threads::shared;
use threads 'exit'=>'threads_only';



#############################################
######## CHECKINGS AND DECLARATIONS
#############################################
my $indir        = $ARGV[0];
my $fastaFile    = $ARGV[1];
my $taxonID      = $ARGV[2];
my $variant		 = $ARGV[3];
my $sequenceType = $ARGV[4];


if ( @ARGV < 4)
{
print "USAGE: $0 </full/path/to/file> <NCBI_taxon_id variant> <sequence_type>\n";
print 
"<NCBI_taxon_id variant>: if a strain or subspecie is not present in ncbi, use the root ncbi id and increment the variant count
        <sequence_type> : CDS          1
                          CHROMOSSOMES 2
                          CIRCULAR     3
                          CONTIGS      4
                          COMPLETE     5
                          GENES        6
                          ORF          7
                          PARTIAL      8
                          WGS SCAFFOLD 9
";
exit(1); 
};

my $fullFastaFile = "$indir/$fastaFile";
if ( ! ( -d $indir         ) ) { die "INPUT  DIR  $indir         DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
if ( ! ( -f $fullFastaFile ) ) { die "INPUT  FILE $fullFastaFile DOESNT EXISTS: $!"};
if ( ! ( -d $outDir        ) ) { mkdir ($outDir)  or die "OUTPUT DIR  $outDir  DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
if ( ! ( -d $sqlDir        ) ) { mkdir ($sqlDir)  or die "SQL    DIR  $sqlDir  DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };
if ( ! ( -d $dumpDir       ) ) { mkdir ($dumpDir) or die "DUMP   DIR  $dumpDir DOESNT EXISTS AND COULD NOT BE CREATED: $!"; };

my %idKey     ;
my @idKeyRev  ;
my $totalSeq  ;
my $totalFrag ;
my @seqKeyRev ;
my $inputFile ;

my $runned      = 0;

####################################################
####### SQL STATEMENTS
####################################################
if ($resetAtStart)
{
	`/home/saulo/Desktop/rolf/sql/sqlDrop.sh`;
}


#############################################
######## INITIATION
#############################################
	my $progStartTime = time;
	my $progTotalBp   = 0;

	unlink("log.txt");
	if ($log >=0)
	{
		open  LOG, ">log" or die "COULD NOT SAVE LOG: $!";
	}

	&printLog(0, "RUNNING OVER FILE $fullFastaFile\n");

	&getFasta($fullFastaFile);

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

	if ($runned)
	{
		&printLog(0,	"$totalSeq SEQUENCES ON FILE $fullFastaFile");
		&printLog(0,	"$progTotalBp bp on " . (time - $progStartTime) . " s [ " . (int(($progTotalBp/(time - $progStartTime))+.5)) . " bp/s ]\n");
	}
	else
	{
		die "A PROBLEM WAS FOUND WHILE RUNNING. PLEASE CHECK YOUR FASTA FILE";
	}
	undef @seqKeyRev;
	undef %idKey;
	undef @idKeyRev;
	undef $totalSeq;
	undef $totalFrag;

close LOG;



#############################################
######## FUNCTIONS
#############################################

sub mkFragments
{
	my $MKFfile  = $_[0];
	my $MKFID    = $_[1];
	my $sequence = uc($_[2]);
	my $id_short = $idKeyRev[$MKFID][0];
	my $id_long  = $idKeyRev[$MKFID][1];
	my %hash;
	$hash{"fastaFile"}     = $fastaFile;
	$hash{"fullFastaFile"} = $fullFastaFile;
	$hash{"taxonID"}       = $taxonID;
	$hash{"variant"}       = $variant;
	$hash{"sequenceType"}  = $sequenceType;
	$hash{"MKFfile"}       = $MKFfile;
	$hash{"MKFID"}         = $MKFID;
	$hash{"id_short"}      = $id_short;
	$hash{"id_long"}       = $id_long;
	$hash{"sequence"}      = $sequence;
	$hash{"outDir"}        = $outDir;
	$hash{"dumpDir"}       = $dumpDir;
	$hash{"sqlDir"}        = $sqlDir;

	my $outName = "$dumpDir/$fastaFile\_$MKFID.xml";
	saveXML(\%hash, $outName);
	%hash=();
#	print system("./probe_extractor_actuator.pl $outName");
#	print "$outName\n\n\n";
	if ( -f $outName )
	{
		#my $response = "";#`./probe_extractor_actuator.pl $outName 2>&1`;
		#if ( $response =~ /DIED/igm )
		#{
		#	&printLog(0, $response);
		#	die "ACTUATOR ERROR > \n$fastaFile :: $outName";
		#}
		#else
		#{
		#	&printLog(1, $response);
		#	&printLog(0, "ACTUATOR OK > $fastaFile :: $outName\n");
		#}
	}
	else
	{
		die "COULD NOT SAVE DUMP FILE $outName";
	}
	return undef;
}


sub getFasta
{
	my $file  = $_[0];
	my @seq;
	my @tmpSeq;
	my $count = 0;
	my $ID;
	my $sequence;
	my @threads;

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
					while (threads->list(threads::running) > ($maxThreads-1))
					{
						sleep($napTime); 
					}

					foreach my $thr (threads->list(threads::joinable))
					{
						$thr->join();
					}

					$progTotalBp += length($sequence);
					&printLog(0, "EXPORTING DUMP FOR $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
					threads->new(\&mkFragments, ($fastaFile, $ID, $sequence));
					$totalSeq++;
				}

				$ID     = substr($line, 1);
				$line   = substr($line, 1);

				#if ($ID =~ /(\S+)\s/) {$ID = $1;};
				$ID =~ tr/ /_/;
				$ID =~ tr/\//_/;
				$ID =~ tr/a-zA-Z0-9_/_/cd;

				if ( ! defined $idKey{$ID})
				{
					my $key            = @idKeyRev;
					$idKey{$ID}        = $key;
					$idKeyRev[$key][0] = $ID;
					$idKeyRev[$key][1] = $line;
					$ID = $key;
				}


				$sequence = "";
			} # end if ^>
			else
			{
				$line = uc($line);
				$line =~ tr/[A|C|T|G|N]/N/cd;
				if ($line =~ /[^ACTGN]/){ die "STRANGE CHARACTER IN FASTA: $line";};
				
				#$line =~ tr/[A|C|T|G|N|a|c|t|g|n]//cd;

# 				print "$_\n";
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

	if ((defined $ID) && ($sequence))
	{
		while (threads->list(threads::running) > ($maxThreads-1))
		{
			sleep($napTime); 
		}

		foreach my $thr (threads->list(threads::joinable))
		{
			$thr->join();
		}

		$progTotalBp += length($sequence);
		&printLog(0, "EXPORTING DUMP FOR $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
		threads->new(\&mkFragments, ($fastaFile, $ID, $sequence));
		$totalSeq++;
	}

	$runned = 1;
	&printLog(0, "$count LINES LOADED FOR $file\n");

	close FILE;
}

# CHECK REVERSE - DO NOT DELETE
#my $m  = substr($MKFsequence, $ligStart-1, ($ligLen+$m13Len));
#my $o  = reverse($sequence);
#   $o  =~ tr/ACTG/TGAC/;
#my $oo = substr($o, $ligStart-1, ($ligLen+$m13Len));
#my $on = substr($o, $m13EndF , ($ligLen+$m13Len));
#   $on =~ tr/ACTG/TGAC/;
#   $on = reverse($on);
#my $on = substr($o, $m13EndF-1 , ($ligLen+$m13Len));
#   $on =~ tr/ACTG/TGAC/;
#   $on = reverse($on);

#my $TmpMKFsequence = $sequence;
   #$TmpMKFsequence =~ tr/ACTG/TGAC/; 
#print "ORIGINAL   : $ligStart\t$m13Start\t$m13End\n";
#print "NEW        : $ligStartF\t$m13StartF\t$m13EndF\n";
#print "LENGTH     : " . length($sequence) . "/" . $MKFsequenceLength . "\n";
#print "ALLSEQ     : " . " "x10 . " $ligStart $MKFligSeq-$MKFm13Seq $m13End ($ligStart $ligLen $m13Start $m13Len)\n";

#print "EXTRACTEDm : " . " $ligStart " . substr($MKFsequence, 0, 5) . " ... " . $m  . " ... " . substr($MKFsequence, -5, 5) . " $m13End\n";
#print "EXTRACTEDoo: " . substr($o          , 0, 5) . " ... " . $oo . " ... " . substr($o          , -5, 5) . "\n";
#print "EXTRACTEDon: " . " $ligStartF " . substr($o          , 0, 5) . " ... " . $on . " ... " . substr($o          , -5, 5) . " $m13EndF [$m13StartF]\n\n\n";
#die;
#print "$MKFallSeq, $allGC, $allTm, $ligStartF, $m13StartF, $m13EndF\n";


#############################################
######## TOOLKIT
#############################################
sub savedump
{
    my $ref     = $_[0]; #reference
    my $name    = $_[1]; #name of variable to save
	my $outFile = $_[2];
    my $d = Data::Dumper->new([$ref],["*$name"]);

    $d->Purity   (1);     # better eval
#   $d->Terse    (0);     # avoid name when possible
    $d->Indent   (3);     # identation
    $d->Useqq    (1);     # use quotes
    $d->Deepcopy (1);     # enable deep copy, no references
    $d->Quotekeys(1);     # clear code
    $d->Sortkeys (1);     # sort keys
    $d->Varname  ($name); # name of variable
#    open (DUMP, ">$outFile.dump") or die "Cant save $outFile.dump file: $!\n";
    print $d->Dump or die "COULD NOT EXPORT HASH DUMP FROM PROBE_EXTRACTOR TO PROBE_EXTRACTOR_ACTUATOR: $!";
#    close DUMP;
};

sub saveXML
{
    my $ref  = $_[0];
    my $file = $_[1];

    if (ref($ref) eq "HASH")
    {
		open DUMPXML, ">$file" or die "COULD NOT SAVE DUMPXML $file: $!";

		print DUMPXML "<xml>\n";
		foreach my $key (sort keys %{$ref})
		{
			my $value = \$ref->{$key};
			$value =~ tr/\n//;
			$value =~ tr/\r//;
			print DUMPXML "\t<", $key, ">",$$value,"</", $key, ">\n";
		}
		print DUMPXML "</xml>\n";
		close DUMPXML;
    }
	else
	{
		die "NOT A HASH REFERENCE";
	}
}


sub loadXML
{
	my $ref  = $_[0];
	my $file = $_[1];

    if (ref($ref) eq "HASH")
    {
		open DUMPXML, "<$file" or die "COULD NOT OPEN DUMPXML $file: $!";
		my $start = 0;
		while (my $line = <DUMPXML>)
		{
			chomp $line;
			if ($line eq "</xml>") { $start = 0; }

			if ($start)
			{
				if ($line =~ /<(.*)>(.*)<\/\1>/)
				{
					print "$1: $2\n";
					$ref->{$1} = $2;
					if ( ! defined $ref->{$1})
					{
						die "COULD NOT EXTRACT INFORMATION FROM XML FILE: $line";
					}
				}
				else
				{
					print "UNKNOWN LINE FORMAT: $line\n";
				}
			}

			if ($line eq "<xml>")  { $start = 1; }
		}
		close DUMPXML;
	}
	else
	{
		die "NOT A HASH REFERENCE";
	}
}

sub save
{
    my $ref  = $_[0];
    my $file = $_[1];
    store $ref, "$file" or die "COULD NOT SAVE DUMP FILE $file: $!";
#	return $ref;
};

sub load
{
    my $ref  = $_[0];
	my $file = $_[1];
#	my $name = $_[1];
    &printLog(0, "LOADING DATABASE....");

    if (ref($ref) eq "HASH")
    {
            %{$ref} = %{retrieve("$file")};
    }
	elsif (ref($ref) eq "ARRAY")
    {
            @{$ref} = @{retrieve("$file")};
    };
	&printLog(0, "done\n");
#	return $ref;
    #%database = %{retrieve($prefix."_".$name."_store.dump")};
};

sub printLog
{
	my $verbo = $_[0];
	my $text  = $_[1];
	my $lTime = time;
	print "\t", $lTime , "\tEXTRACTOR: ", $text if ( $verbo <= $log );

	if ($verbo <= $log)
	{
		print LOG $lTime , "\tEXTRACTOR: ", $text;
	}
}

1;

