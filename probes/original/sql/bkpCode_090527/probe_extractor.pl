#!/usr/bin/perl -w
use warnings;
use strict;
use Storable;
use Data::Dumper;


#############################################
######## SETUP
#############################################
my $log          = 0; #HOW VERBOSY 
my $maxThreads   = 3;	
my $resetAtStart = 0;
my $napTime      = 1;
my $dumpsDir     = "/mnt/ssd/probes/dumps";

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
my $file         = $ARGV[1];
my $taxonID      = $ARGV[2];
my $variant		 = $ARGV[3];
my $sequenceType = $ARGV[4];


if ( ! (@ARGV[0 .. 4]))
{
print "USAGE: $0 indir file NCBI_taxon_id variant sequence_type\n";
print "       variant: if a strain or subspecie is not present in ncbi, use the root ncbi id and increment the variant count\n";
print 
"       sequence type: CDS          1
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

if ( ! ( -d $indir         ) ) { die "INPUT  DIR $indir   DOESNT EXISTS: $!"};
if ( ! ( -f "$indir/$file" ) ) { die "INPUT  FILE $file   DOESNT EXISTS: $!"};

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
	`/home/saulo/Desktop/rolf/sql/startSql.sh`;
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

	&printLog(0, "RUNNING OVER FILE $indir/$file\n");

	&getFasta("$indir/$file");

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
		&printLog(0,	"$totalSeq SEQUENCES ON FILE $indir/$file");
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
	my $id_name  = $idKeyRev[$MKFID][1];
	my %hash;
	$hash{"indir"}        = $indir;
	$hash{"file"}         = $file;
	$hash{"taxonID"}      = $taxonID;
	$hash{"variant"}      = $variant;
	$hash{"sequenceType"} = $sequenceType;
	$hash{"MKFfile"}      = $MKFfile;
	$hash{"MKFID"}        = $MKFID;
	$hash{"id_name"}      = $id_name;
	$hash{"sequence"}     = $sequence;

	my $outName = "$dumpsDir/$file\_$MKFID.dump";
	save(\%hash, $outName);
	%hash=();
	print system("./probe_extractor_actuator.pl $outName");
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
	while (<FILE>)
	{
		chomp $_;
		$count++;
		if ($_)
		{
			if (substr($_,0,1) eq '>')
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
#					&printLog(0, "MAKING FRAGMENTS FOR $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
					threads->new(\&mkFragments, ($file, $ID, $sequence));
					$totalSeq++;
				}

				$ID     = substr($_, 1);
				$_      = substr($_, 1);
				if ($ID =~ /(\S+)\s/) {$ID = $1;};
				$ID =~ tr/ /_/;
				$ID =~ tr/\//_/;
				$ID =~ tr/a-zA-Z0-9_/_/cd;

				my $key;
				if (defined $idKey{$ID})
				{
					$key = $idKey{$ID}
				}
				else
				{
					$key               = @idKeyRev;
					$idKey{$ID}        = $key;
					$idKeyRev[$key][0] = $ID;
					$idKeyRev[$key][1] = $_;
				}
				$ID = $key;

				$sequence = "";
			}
			else
			{
				$_ =~ tr/[A|C|T|G|N|a|c|t|g|n]//cd;
				$_ = uc($_);
# 				print "$_\n";
				if ((defined $ID) && ($ID ne "") && ($ID ne " "))
				{
					$sequence .= $_;
				}
			}
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
		&printLog(0, "MAKING FRAGMENTS FOR $file " . $idKeyRev[$ID][1] . "[$ID] (" . length($sequence) . "bp)\n");
		threads->new(\&mkFragments, ($file, $ID, $sequence));
		$totalSeq++;
	}

	$runned = 1;
	print "$count LINES LOADED FOR $file\n";

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
    print $d->Dump;
#    close DUMP;
};


sub save
{
        my $ref  = $_[0];
        my $file = $_[1];
        store $ref, "$file";
#	return $ref;
};

sub load
{
        my $ref  = $_[0];
		my $file = $_[1];
#	my $name = $_[1];
        print "LOADING DATABASE....";

        if (ref($ref) eq "HASH")
        {
                %{$ref} = %{retrieve("$file")};
        }
	elsif (ref($ref) eq "ARRAY")
        {
                @{$ref} = @{retrieve("$file")};
        };
	print "done\n";
#	return $ref;
        #%database = %{retrieve($prefix."_".$name."_store.dump")};
};

sub printLog
{
	my $verbo = $_[0];
	my $text  = $_[1];
	print $text if ( $verbo <= $log );

	if ($verbo <= $log)
	{
		print LOG time , "\t", $text;
	}
}

1;

