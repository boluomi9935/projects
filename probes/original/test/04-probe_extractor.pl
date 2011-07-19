#!/usr/bin/perl -w
use warnings;
use strict;

#############################################
######## SETUP
#############################################
my $maxGCLS    = 2; #MAX NUMBER OF CG ALLOWED IN THE LIGANT SITE
my $log        = 0; #HOW VERBOSY 
my $makeHash   = 1; #MAKE ELABORATED REPORT
my $maxThreads = 12;
my $napTime    = 1;

my @ligLen    = qw( 21 23 24 26 27 29 30 32 33 35 36 38 39 );
my $ligMinGc  = 45;
my $ligMaxGc  = 60;
my $ligMinTm  = 69;
my $ligMaxTm  = 76;

my @m13Len    = qw( 37 38 40 41 43 44 46 47 49 50 );
my $m13MinGc  =  35;
my $m13MaxGc  =  60;
my $m13MinTm  =  70;
my $m13MaxTm  = 100;



#############################################
######## USAGE DECLARATIONS
#############################################
`sudo renice -10 $$`;
use List::Util qw[min max];

use IO::Socket;
# http://www.rocketaware.com/perl/perlipc/TCP_Servers_with_IO_Socket.htm

use DB_File;
use Fcntl;

# use Tie::FlatFile::Array;
# use Tie::Hash;

use Fcntl ':flock';
use threads;
use threads::shared;
use threads 'exit'=>'threads_only';



#############################################
######## CHECKINGS
#############################################
my $outdir     = $ARGV[0];
my $indir      = $ARGV[1];
my $file       = $ARGV[2];


if ( ! (@ARGV[0 .. 2])) { print "USAGE $0 outdir indir file\n"; exit(1); };

if ( ! ( -d $outdir        ) ) { die "OUTPUT DIR $outdir DOESNT EXISTS: $!"};
if ( ! ( -d $indir         ) ) { die "INPUT  DIR $indir  DOESNT EXISTS: $!"};
if ( ! ( -f "$indir/$file" ) ) { die "INPUT FILE $file   DOESNT EXISTS: $!"};


my %idKey     ;
my @idKeyRev  ;
my $totalSeq  ;
my $totalFrag ;
my @seqKeyRev ;

my $ligSize   = @ligLen;
my $m13Size   = @m13Len;
my $minLigLen = min(@ligLen);
my $minM13Len = min(@m13Len);

# my @db;

# my $dbFile = "$outdir/$file.db";
# unlink($dbFile);

my $WCkeyS;
my $countDB    = 0;
my $countDBLig = 0;
my $countDBM13 = 0;

my $host = 'localhost';
my $port = 9000;
my $handle;

# my $seqKey;
# my %seqKey  :shared;
# %seqKey = &share({});
# share(%seqKey);
# my  %seqKey;
# tie %seqKey, 'DB_File', $dbFile, O_CREAT | O_RDWR, 0644, $DB_BTREE or die "Unable to open dbm file $dbFile: $!";

# $seqKey = \%seqKey;
# bless(\$seqKey, 'DB_File');
# share($seqKey);
# %seqKey = &share({});
# bless(%seqKey, 'DB_File');



#############################################
######## INITIATION
#############################################
	mkdir($outdir);

	unlink("log.txt");
	if ($log >=0)
	{
		open  LOG, ">log" or die "COULD NOT SAVE LOG: $!";
	}

	&printLog(0, "RUNNING OVER FILE $indir/$file AND OUTPUT ON $outdir\n");

	opendir (DIR, "$outdir") or die $!;
	my @outfiles = grep /$file.*\.wc.*$/, readdir(DIR);
	closedir DIR;

	foreach my $tfile (@outfiles) {
	# 	print "$tfile\n";
		&printLog(1,"DELETING FILE $outdir/$tfile\n");
		unlink ("$outdir/$tfile") or die $!;
	} 

# 	open  WCFILE1, ">$outdir/$file.wc"     or die "COULD NOT SAVE WC FILE $file.wc: $!";
# 	open  WCFILE2, ">$outdir/$file.lig.wc" or die "COULD NOT SAVE WC FILE $file.lig.wc: $!";
# 	open  WCFILE3, ">$outdir/$file.m13.wc" or die "COULD NOT SAVE WC FILE $file.m13.wc: $!";
# 	open  WCFILE4, ">$outdir/$file.pro.wc" or die "COULD NOT SAVE WC FILE $file.pro.wc: $!";
# 	print WCFILE1 "LIG\tM13\t[LIGGC,M13GC,ALLGC]\t[LIGTM,M13TM,ALLTM]\t[CONTIG,LIGSTART,M13START]\n";

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

	&printLog(0,   "$totalSeq SEQUENCES ON FILE $indir/$file" .
			" LIG GC% ] $ligMinGc,$ligMaxGc [, M13 GC% ] $m13MinGc,$m13MaxGc [," .
			" LIG TM  ] $ligMinTm,$ligMaxTm [, M13 TM  ] $m13MinTm,$m13MaxTm [," .
			" LENGTH LIG ( " . $ligSize . " ), LENGTH M13 ( " . $m13Size . " )\ndone\n");

# 	&printLog(0, "\t$countDB UNIQUE PROBES EXPORTED\n");
# 	&printLog(0, "\t$countDBLig UNIQUE LIG PROBES EXPORTED\n");
# 	&printLog(0, "\t$countDBM13 UNIQUE M13 PROBES EXPORTED\n");


# 	close WCFILE4;
# 	close WCFILE3;
# 	close WCFILE2;
# 	close WCFILE1;

# 	undef @db;
# 	untie %seqKey;

	undef @seqKeyRev;
	undef %idKey;
	undef @idKeyRev;
	undef $totalSeq;
	undef $totalFrag;

# &shutdownServer();

close LOG;



#############################################
######## FUNCTIONS
#############################################
sub mkFragments
{
	my $MKFfile  = $_[0];
	my $MKFID	 = $_[1];
	my $sequence = uc($_[2]);
	my $revC     = 0;
	my $rev;

	$0 = "$0 :: $MKFfile : $MKFID";

	my $MKFsequenceLength = length($sequence);
	my $lastLigStart      = $MKFsequenceLength - ($minLigLen + $minM13Len);

	my $ligEnd;
	my $m13Start;
	my $m13End;
	my $MKFligSeq;
	my $MKFm13Seq;
	my $ligThree;
	my $m13Three;
	my $countValAll = 0;

	for my $MKFsequence ($sequence, $sequence)
	{
		if ($revC) 
		{
			$rev = " REV"; 
			$MKFsequence = reverse($MKFsequence);  
			$MKFsequence =~ tr/ACTG/TGAC/; 
		}
		else 
		{ 
			$rev = " FWD"; 
		};

		my $ligStart = 1;
		my $count    = 1;
		my $total    = $lastLigStart;
		my $centimo  = int(($total / 10) + 0.5);

		undef $ligEnd;
		undef $m13Start;
		undef $m13End;
		undef $MKFligSeq;
		undef $MKFm13Seq;
		undef $ligThree;
		undef $m13Three;

		while ($ligStart < $lastLigStart)
		{
			my $ligLen;
			if ( ! ($ligStart % $centimo) ) { print "\t\t$MKFfile " . $idKeyRev[$MKFID] . "$rev: POS $ligStart\tout of $total\t" . (int(((int(($ligStart/$total)*1000))/10)+.5)) . "%\n"; };

			for $ligLen (@ligLen)
			{
				$ligEnd    = $ligStart + $ligLen - 1;
				$MKFligSeq = substr($MKFsequence, $ligStart-1, $ligLen);

				############# LIG CONSTRAINS ##################
				my $start = 0;

				while ((substr($MKFligSeq, $start, 1) =~ /[A|T]/) && ($start < $ligLen)) { $ligStart++; $start++; };

				if ( $MKFligSeq =~ /^[A|T]/) { $ligStart--; last; }; # &printLog(2, "LIG STARTS WITH A|T OR ENDS WITH G|T\t$MKFligSeq\n");

				if ( $MKFligSeq =~ /[G|T]$/) { next; }; # &printLog(2, "LIG STARTS WITH A|T OR ENDS WITH G|T\t$MKFligSeq\n"); 

				my $ligGC   = &countGC($MKFligSeq);
				if ( ! (($ligGC >=       $ligMinGc)  && ($ligGC <=      $ligMaxGc))  ) { next; }; # &printLog(2, "LIG WRONG GC% $ligMinGc < $ligGC < $ligMaxGc\t$MKFligSeq\n");

				my $ligTm   = &tm($MKFligSeq, $ligGC);
				if      ($ligTm > $ligMaxTm)                                           { last; }; # &printLog(2, "LIG WRONG TM $ligMinTm < $ligTm < $ligMaxTm\t$MKFligSeq\n"); 
				if ( ! (($ligTm >=       $ligMinTm)  && ($ligTm <=      $ligMaxTm))  ) { next; }; # &printLog(2, "LIG WRONG TM $ligMinTm < $ligTm < $ligMaxTm\t$MKFligSeq\n"); 

				$ligThree = substr($MKFligSeq, -3);
				if (($ligThree =~ s/[G|C]//g) > $maxGCLS) { next; }; # &printLog(2, "LIG ENDS WITH TOO MUCH GC\t$MKFligSeq\n"); 


				my $m13Len;
				for $m13Len (@m13Len)
				{
					if ( ! ($m13Len % 3) ) { next; };

					$m13Start = $ligEnd   + 1;
					$m13End   = $m13Start + $m13Len + 1;
					if ( $m13End > $MKFsequenceLength ) { last; };

					############# M13 CONSTRAINS ##################
					$MKFm13Seq   = substr($MKFsequence, $m13Start-1, $m13Len);
					if (($MKFm13Seq =~ /GAATGC/) || ($MKFm13Seq =~ /CTTACG/) ||	# #BSM1
						($MKFm13Seq =~ /GATATC/) || ($MKFm13Seq =~ /CTATAG/) ||	#ECORV
						($MKFm13Seq =~ /GAGCTC/) || ($MKFm13Seq =~ /CTCGAG/))	#SCAI
						{ last; }; 

					my $m13GC   = &countGC($MKFm13Seq);
					if ( ! (($m13GC >= $m13MinGc)        && ($m13GC <=      $m13MaxGc))  ) { next; }; # &printLog(2, "M13 WRONG GC% $m13MinGc < $m13GC < $m13MaxGc\t$MKFm13Seq\n"); 

					my $m13Tm = &tm($MKFm13Seq, $m13GC);
					if ( $m13Tm > $m13MaxTm)                                               { last; }; #&printLog(2, "M13 WRONG TM $m13MinTm < $m13Tm < $m13MaxTm\t$MKFm13Seq\n"); 
					if ( ! (($m13Tm >=       $m13MinTm)  && ($m13Tm <=      $m13MaxTm))  ) { next; }; #&printLog(2, "M13 WRONG TM $m13MinTm < $m13Tm < $m13MaxTm\t$MKFm13Seq\n"); 

					$m13Three = substr($MKFm13Seq, 0, 3);
					if (($m13Three =~ s/[G|C]//g) > $maxGCLS) { next; }; #&printLog(2, "M13 STARTS WITH TOO MUCH GC\t$MKFm13Seq\n"); 


					my $MKFallSeq = "$MKFligSeq$MKFm13Seq";
					my $allGC     = &countGC($MKFallSeq); # todo, delete to be faster
					my $allTm     = &tm($MKFallSeq, $allGC);




					$handle = IO::Socket::UNIX->new(Peer  => '/tmp/server.sock',
												Type      => SOCK_STREAM)
						or die "can't connect to port : $!";

					die "can't setup client: $!" unless $handle;
					$handle->autoflush(1); 
					my $id = $MKFfile . "_" . $MKFID . "_" . $ligStart . "_" . $m13Start . "_" . $m13End;
# 					print         "$id\t$MKFligSeq\t$MKFm13Seq\t$MKFallSeq\n";
					print $handle "$id\t$MKFligSeq\t$MKFm13Seq\t$MKFallSeq\n";

					my $result;
					while(<$handle>) { $result .= $_; };
# 					print  "RESULT $result\n\n";
					die "NO RESULT OBTAINED FROM SERVER\n"       unless (defined $result);
					die "NO VALID RESULT OBTAINED FROM SERVER\n" unless ($result =~ /$id\t(.*)/);

					shutdown ($handle, 2) or die "COULD NOT CLOSE HANDLE: $!";
					$handle->close()      or die "COULD NOT CLOSE HANDLE: $!";

# 					my $result;
# 					while (<$handle>)
# 					{
# 						if ($_ =~ /$id\t(.*)/)
# 						{
# 							$result = $1;
# 						}
# 						else
# 						{
# 							last;
# 						}
# 					}

# 					chomp $result;
				# 	print "QUESTION $id\t$ligKey\t$m13Key\t$proKey\nANSWER: $result\n";
# 					my @result = split('', $result);

# 					print @result;
# 					print "\n";

# 					my @result = &checkKey($MKFfile, $MKFID, $ligStart, $m13Start, $m13End, $MKFligSeq, $MKFm13Seq, $MKFallSeq);
# 					my @result = (1, 1, 1);

# 					if ( $result[0] )
# 					{
# 						flock(WCFILE2, LOCK_EX) or die "COULD NOT GET A LOCK ON FILE WC2: $!";
# 						print WCFILE2 $MKFligSeq . "\n";
# 						flock(WCFILE2, LOCK_UN);
# # 						print "ADDING LIG $MKFligSeq " . $result[0] . "\n";
# 					}

# 					if ( $result[1] )
# 					{
# 						flock(WCFILE3, LOCK_EX) or die "COULD NOT GET A LOCK ON FILE WC3: $!";
# 						print WCFILE3 $MKFm13Seq . "\n";
# 						flock(WCFILE3, LOCK_UN);
# # 						print "ADDING M13 $MKFligSeq " . $result[1] . "\n";
# 					}

# 					if ( $result[2] )
# 					{
# 						flock(WCFILE1, LOCK_EX) or die "COULD NOT GET A LOCK ON FILE WC1: $!";
# 						print WCFILE1 "$MKFm13Seq\t$MKFligSeq\t[$ligGC,$m13GC,$allGC]\t[$ligTm,$m13Tm,$allTm]\t[$ligStart,$m13Start,$MKFID]\n";
# 						flock(WCFILE1, LOCK_UN);
# 						flock(WCFILE4, LOCK_EX) or die "COULD NOT GET A LOCK ON FILE WC4: $!";
# 						print WCFILE4 "$MKFm13Seq\t$MKFligSeq\n";
# 						flock(WCFILE4, LOCK_UN);
# # 						print "ADDING PRO $MKFligSeq $MKFm13Seq " . $result[2] . "\n";
# 					}

					$countValAll++;
				} #END FOR MY M13LEN
# 				&quitServer();
			} #END FOR MY LIGLEN
		$ligStart++;
		} # END FOR MY $LIGSTART

# 		&printLog(0, "\t$countVal FRAGMENTS GENERATED FROM $MKFfile $MKFID " . length($MKFsequence) . "BP\n");
	$revC++;
	} # end foreach my $sequence revComp(sequence)
	print "\t$countValAll PROBES GENERATED FROM $MKFfile $MKFID\n";

	return undef;
}



sub checkKey
{
	my $file     = $_[0];
	my $ID	     = $_[1];
	my $ligStart = $_[2];
	my $m13Start = $_[3];
	my $m13End   = $_[4];
	my $ligKey   = $_[5];
	my $m13Key   = $_[6];
	my $proKey   = $_[7];
	my $result;

	&startServer();
# 	my ($handle, $line);
# 	# create a tcp connection to the specified host and port
# 	$handle = IO::Socket::INET->new(Proto     => "tcp",
# 									PeerAddr  => $host,
# 									PeerPort  => $port,
# 									Reuse     => 1,
# 									ReuseAddr => 1)
# 			or die "can't connect to port $port on $host: $!";
# 
# 	die "can't setup client: $!" unless $handle;
# 	$handle->autoflush(1);              # so output gets there right away
	my $id = $file . "_" . $ID . "_" . $ligStart . "_" . $m13Start . "_" . $m13End;
	print $handle "$id\t$ligKey\t$m13Key\t$proKey\n";

	while (<$handle>)
	{
		if ($_ =~ /$id\t(.*)/)
		{
			$result = $1;
		}
		else
		{
			last;
		}
	}

	if ( ! ( defined $result ) ) { die "NO RESULT OBTAINED FROM SERVER\n"; };

	chomp $result;
# 	print "QUESTION $id\t$ligKey\t$m13Key\t$proKey\nANSWER: $result\n";
	my @result = split('', $result);
	return @result;
}

sub startServer
{
	# create a tcp connection to the specified host and port
# 	$handle = IO::Socket::INET->new(Proto     => "tcp",
# 									PeerAddr  => $host,
# 									PeerPort  => $port,
# 									Reuse     => 1,
# 									ReuseAddr => 1)
# 			or die "can't connect to port $port on $host: $!";

	$handle = IO::Socket::UNIX->new(Peer  => '/tmp/server.sock',
								Type      => SOCK_STREAM,
								TimeOut   => 1)
		or die "can't connect to port : $!";

	die "can't setup client: $!" unless $handle;
	$handle->autoflush(1);              # so output gets there right away
# 	print "STARTING SERVER\n";
}

sub shutdownServer
{
	$handle = IO::Socket::UNIX->new(Peer  => '/tmp/server.sock',
								Type      => SOCK_STREAM,
								TimeOut   => 1)
		or die "can't connect to port : $!";

	die "can't setup client: $!" unless $handle;
	$handle->autoflush(1); 

	print "SHUTDOWN SERVER\n";
	print $handle "shutdown\n";
	my $result;

	while (<$handle>)
	{
		$result .= $_;
	}

	if ( ! ( defined $result ) ) { die "NO RESULT OBTAINED FROM SERVER\n"; };

	chomp $result;
	print "SERVER STATISTICS\n";
	print $result;
}

sub getFasta
{
	my $file   = $_[0];
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

					&printLog(0, "MAKING FRAGMENTS FOR $file " . $idKeyRev[$ID] . "[$ID] (" . length($sequence) . "bp)\n");
					threads->new(\&mkFragments, ($file, $ID, $sequence));

					$totalSeq++;
				}

				$ID     = substr($_, 1);
				if ($ID =~ /(\S+)\s/) {$ID = $1;};
				$ID     =~ tr/a-zA-Z0-9/_/cd;

				my $key;
				if (defined $idKey{$ID})
				{
					$key = $idKey{$ID}
				}
				else
				{
					$key            = @idKeyRev;
					$idKey{$ID}     = $key;
					$idKeyRev[$key] = $ID;
				}
				$ID = $key;

				$sequence = "";
			}
			else
			{
				$_ =~ tr/[A|C|T|G|a|c|t|g]//cd;
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

		&printLog(0, "MAKING FRAGMENTS FOR $file " . $idKeyRev[$ID] . "[$ID] (" . length($sequence) . "bp)\n");
		threads->new(\&mkFragments, ($file, $ID, $sequence));

		$totalSeq++;
	}

	print "$count LINES LOADED\n";

	close FILE;
}



#############################################
######## TOOLKIT
#############################################
sub revComp
{
	my $sequence = uc($_[0]);
	my $rev = reverse($sequence);
	$rev =~ tr/ACTG/TGAC/;
	return $rev;
}


sub printLog
{
	my $verbo = $_[0];
	my $text  = $_[1];
	print $text if ( $verbo <= $log );

	if ($verbo <= $log)
	{
		print LOG time . "\t$text";
	}
}


sub tm
{
	my $seq       = $_[0];
	my $gc        = $_[1];
	my $NaK       = 0.05; # 35mM 0.035M
# 	my $cgCount   = $seq;
# 	   $cgCount   = ($cgCount =~ s/[C|G]//gi);;

	my $tm   = 81.5    + (16.6    *  (&log10($NaK)))       + (0.41   *   $gc)   - (675/length($seq));
#       Tm   = 81.5°C  +  16.6°C  x  (log10[Na+] + [K+])  +  0.41°C  x  (%GC)  –  675/N

	$tm = (1.0701*$tm) + 14.646; # regression from 4 points to raw-probe
	
	return int($tm + .5);


#http://www.promega.com/biomath/calc11.htm#melt_results
#Where N is the length of the primer.

}



sub log10 {
	my $n = shift;
	return log($n)/log(10);
}


sub countGC
{
	my $seqGC    = $_[0];
	my $lengthGC = length($seqGC);
# 	print "$seq (" . length($seq) . ")\t";
	my $count    = ($seqGC =~ s/[C|G]//gi);
# 	print "$seq (" . length($seq) . ")\t$count\t";
	my $gc       = ($count / $lengthGC) * 100;
# 	print "gc $gc\n";
	return int($gc + .5);
}


sub digit2dna
{
	my $seq  = $_[0];

# 	print "$seq (" . length($seq) . ") > ";
	my $extra = "";
	if ( $seq =~ /([[:^lower:]]*)([[:lower:]]+)/)
	{
		$seq   = $1;
		$extra = uc($2);
	}
# 	print "$seq (" . length($seq) . ") + $extra (" . length($extra) . ") >> ";

	my $BASE = 4;
	my @str_digits;
	for (my $s = 0; $s < length($seq); $s+=2)
	{
		my $subSeq  = substr($seq, $s, 2);
		my $subs    = 0;

		$subSeq     = hex($subSeq);
		my @digits  = (0) x 4; # cria o array @digits composto de 4 zeros

		my $i = 0; 
# 		print "$subSeq\t";
		while ($subSeq) { # loop para decompor o numero
				$digits[4 - ++$i] = $subSeq % $BASE;
				$subSeq = int ($subSeq / $BASE);
		}
# 		print "@digits\t"; # imprime o codigo ascII transformado em base 4
		my $subJoin = join("", @digits);
		$subJoin =~ tr/0123/ACGT/;
# 		print "$subJoin\n"; # imprime o codigo ascII transformado em base 4
		push @str_digits, $subJoin;    # salva todos os codigos ascII em base
										# 4 gerados no array. cada elemento deste
									    # array ser� um outro array de 4 elementos..
	}
	my $join = join("", @str_digits);
# 	print "$join (" . length($join) . ") -> ";
	$join .= $extra;
# 	print "$join (" . length($join) . ")\n\n";
	return $join;
# 	print "Hex: $seq  " . length($seq)      . "\n";
# 	print "Seq: $join " . length($sequence) . "\n";
}

sub dna2digit
{
	my $input = uc($_[0]);
	my $extra = "";
# 	print "$input (" . length($input) . ") > ";
	while (length($input) % 4) { $extra = chop($input) . $extra; };

# 	print "$input (" . length($input) . ") + $extra (" . length($extra) . ")";

#     print "Seq: $input " . length($input) . "\n";
	$input =~ s/\r//g;
	$input =~ s/\n//g;
	$input =~ tr/ACGTacgt/01230123/;
# 	print "Inp: $input "    . length($input)    . "\n";
	my $outputHex; my $outputHexStr;
	my $outputDec; my $outputDecStr;

	for (my $i = 0; $i < length($input); $i+=4)
	{
		my $subInput = substr($input, $i, 4);
		#print "$i - $subInput\n";
# 		my $subInputDec = $subInput;
		my $subInputHex = $subInput;

		$subInputHex =~ s/(.)(.)(.)(.)/(64*$1)+(16*$2)+(4*$3)+$4/gex;
# 		$subInputDec =~ s/(.)(.)(.)(.)/(64*$1)+(16*$2)+(4*$3)+$4/gex;

		$subInputHex = sprintf("%X", $subInputHex);
		if (length($subInputHex) <   2) {$subInputHex = "0$subInputHex"; };
# 		if ($subInputDec         < 100) {$outputDecStr .= "_" ; };

		$outputHex    .= $subInputHex;
# 		$outputHexStr .= "__" . $subInputHex;
# 
# 		$outputDec    .= $subInputDec;
# 		$outputDecStr .= "_" . $subInputDec;
	}
	if ($extra)
	{
		$outputHex .= lc($extra);
	}
# 	print " >> $outputHex (" . length($outputHex) . ")\n";
# 	&digit2dna($outputHex);
# 	print "Dec: $outputDecStr " . length($outputDec) . "\n";
# 	print "Hex: $outputHexStr " . length($outputHex) . "\n";
	return $outputHex;
}



1;









# sub checkSeq
# {
# 	my $seq    = $_[0];
# 	   $seq    = uc($seq);
# 
# 	for (my $ligE = 19; $ligE <= 47; $ligE++)
# 	{
# 		my $subSeq = substr($seq, $ligE-1, 6);
# 		my $third  = substr($subSeq, 2, 1);
# 		my $stHalf = substr($subSeq, 0, 3);
# 		my $ndHalf = substr($subSeq, 3, 3);
# 		$stHalf = ($stHalf =~ s/[G|C]//gi);
# 		$ndHalf = ($ndHalf =~ s/[G|C]//gi);
# 		my $resultSeq = 0;
# 		if (( $third ne "G") && ( $third ne "T"))	{ $resultSeq++ } else { $resultSeq = 0 }; 
# 		if ($stHalf < 3) 							{ $resultSeq++ } else { $resultSeq = 0 }; 
# 		if ($ndHalf < 3)							{ $resultSeq++ } else { $resultSeq = 0 };
# 
# 		if ($resultSeq == 3)
# 		{
# 			my $ligStart = ($ligE+2) - 29;
# 			while ($ligStart < 1) {$ligStart++};
# 			my $ligEnd   = ($ligE+2);
# 			my $ligLen   = $ligEnd - $ligStart + 1;
# 
# 			my $m13Start = ($ligE+3);
# 			my $m13End   = length($seq);
# 			while (($m13End - ($ligE+3)) > 46) {$m13End--};
# 			my $m13Len   = $m13End - $m13Start + 1;
# 
# 			my $ligStartTemp = $ligStart;
# 			my $m13EndTemp   = $m13End;
# 
# 			while (($ligLen >= 21) && ($ligLen <= 30))
# 			{
# 			while (($m13Len >= 28) && ($m13Len <= 47))
# 			{
# 				if ( ! ($m13Len % 3))
# 				{
# 					$m13EndTemp--;
# 					$m13Len   = $m13EndTemp - $m13Start + 1;
# 					next;
# 				};
# 
# 				my $ligSeq   = substr($seq,$ligStartTemp-1 ,$ligLen);
# 				my $ligLenC  = length($ligSeq);
# 
# 				my $m13Seq   = substr($seq,$m13Start-1 ,$m13Len);
# 				my $m13LenC  = length($m13Seq);
# 
# 				my $ligGC    = &countGC($ligSeq)*100;
# 				my $m13GC    = &countGC($m13Seq)*100;
# 
# 				my $allSeq   = "$ligSeq . $m13Seq";
# 				my $allGC    = &countGC($allSeq)*100;
# 				my $allTm    = &tm($allSeq, $allGC);
# 
# 				if ( ! ( $ligSeq =~ /^[A|T]/))
# 				{
# 					if (($ligGC >= 45) && ($ligGC <= 60))
# 					{
# 						if (($m13GC >= 35) && ($m13GC <= 60))
# 						{
# 							my $ligTm = &tm($ligSeq, $ligGC);
# 							if ($allTm >= 70)
# 							{
# 								my $m13Tm = &tm($m13Seq, $m13GC);
# 								my $resultRest = 0;
# 								if ( ! (($m13Seq =~ /GAATGC/) || ($m13Seq =~ /CTTACG/)))	{ $resultRest++ } else { $resultRest = 0 }; #BSM1
# 								if ( ! (($m13Seq =~ /GATATC/) || ($m13Seq =~ /CTATAG/)))	{ $resultRest++ } else { $resultRest = 0 }; #ECORV
# 								if ( ! (($m13Seq =~ /GAGCTC/) || ($m13Seq =~ /CTCGAG/)))	{ $resultRest++ } else { $resultRest = 0 }; #SCAI
# 
# 								if ($resultRest == 3)
# 								{
# 									print "$seq - GC $allGC - tm $allTm\n";
# 									print " " x ($ligStartTemp-1) . "$ligSeq -> Lig $ligStartTemp $ligEnd ($ligLen - $ligLenC) - GC $ligGC - tm $ligTm\n";
# 									print " " x ($m13Start-1)     . "$m13Seq -> M13 $m13Start $m13EndTemp ($m13Len - $m13LenC) - GC $m13GC - tm $m13Tm\n";
# # 									push
# 									print "\n";
# 								} #end if resultrest == 3
# 								else
# 								{
# 	# 	 								print "$seq $resultRest\n";
# 								}
# 							} #end if ligtm > 70
# 
# 						} #end if m13gc
# 					} #end if liggc
# 				}
# 
# 				$m13EndTemp--;
# 				$m13Len   = $m13EndTemp - $m13Start + 1;
# 			}
# 			$ligStartTemp--;
# 			$ligLen   = $ligEnd - $ligStartTemp + 1;
# 			}
# 
# 			#my $coordinate = "$shift," . ($ligE+2);
# 			#push(@seqs, $coordinate); print " "x($ligE-1) . $subSeq . " $ligE -> $coordinate\n";
# 		};
# 	}
# 	return 0;
# }


# sub mkFragments2
# {
# 	my $file     = $_[0];
# 	my $ID		 = $_[1];
# 	my $sequence = $_[2];
# 
# 	my $count = 0;
# 	print "MAKING FRAGMENTS FOR $file " . $idKeyRev[$ID] . " [$ID] (" . length($sequence) . "bp)\n";
# 	for (my $length = $lengthMin; $length <= $lengthMax; $length++)
# 	{
# 		my $countLen = 0;
# 		my $maxS     = (length($sequence) - $length + 1);
# 		print "\t\tFRAGMENT LENGTH = $length\n";
# 		for (my $s = 0; $s < $maxS; $s++)
# 		{
# 			my $subSeq = substr($sequence, $s, $length);
# 			&mkDb($file, $ID, $s, $subSeq);
# 			$count++;
# 			$countLen++;
# 			$totalFrag++;
# 		}
# 		print "\t$countLen FRAGMENTS GENERATED FROM " . length($sequence) . "BP SEQUENCE WITH FL=$length\n";
# 	}
# 	print "$count FRAGMENTS GENERATED FROM " . length($sequence) . "BP SEQUENCE WITH $lengthMin <= FL <= $lengthMax\n";
# }



# 01 -       1 - 1 - 1.000
# 02 -       8 - 1 - 0.500
# 03 -      64 - 2 - 0.660
# 04 -     256 - 3 - 0.750
# 05 -    1024 - 4 - 0.800
# 06 -    4096 - 4 - 0.660
# 07 -   16384 - 5 - 0.710
# 08 -   65536 - 5 - 0.625
# 09 -  232144 - 6 - 0.660
# 10 - 1048576 - 7 - 0.700

# a 0  c 1  t 2  g 3
# aaaa -> 0*64 + 0*16 + 0*4 + 0*1 =   0 +  0 +  0 + 0 =   0 =  0
# actg -> 0*64 + 1*16 + 2*4 + 3*1 =   0 + 16 +  8 + 3 =  27 = 1b
# cccc -> 1*64 + 1*16 + 1*4 + 1*1 =  64 + 16 +  4 + 1 =  85 = 55
# gggg -> 3*64 + 3*16 + 3*4 + 3*1 = 192 + 48 + 12 + 3 = 155 = 9b

# my $hex  = &dna2digit($sequence);
# my $back = &digit2dna($hex);




# sub exportWc
# {
# 	my $file = $_[0];
# 
# 	open  WCFILE1, ">$file.wc"     or die "COULD NOT SAVE WC FILE $file.wc: $!";
# 	open  WCFILE2, ">$file.lig.wc" or die "COULD NOT SAVE WC FILE $file.lig.wc: $!";
# 	open  WCFILE3, ">$file.m13.wc" or die "COULD NOT SAVE WC FILE $file.m13.wc: $!";
# 	print WCFILE1 "PROBE\tCOUNT\t[LIGGC,M13GC,ALLGC]\t[LIGTM,M13TM,ALLTM]\t[CONTIG,LIGSTART,M13START]\n";
# # 	print WCFILE2 "PROBE\tLIG\n";
# # 	print WCFILE3 "PROBE\tM13\n";
# 
# 	&printLog(0, "EXPORTING WORD COUNT\n");
# 	my $dbSize     = @db;
# 	my $centesimo  = ($dbSize >= 10) ? ($dbSize / 10) : 1;
# 	my $countDB    = 0;
# 	my $countDBLig = 0;
# 	my $countDBM13 = 0;
# 
# 	for (my $key = 0; $key < @db; $key++)
# 	{
# 		&printLog(0, "$key / " . $dbSize . "[$centesimo]\n") if ( ! (($key+1) % $centesimo));
# 		if ( ! defined $db[$key] ) { next };
# 
# 		   $WCkeyS  = $db[$key][0];
# 		my $keyType = $db[$key][1];
# 		my $count   = $db[$key][2];
# 		my $gc      = $db[$key][3];
# 		my $tm      = $db[$key][4];
# 
# 		my @pos   = @{$db[$key][5]};
# 
# # 		my $poses = "";
# # 		my $lastPos;
# # 		if (@pos >= 1)
# # 		{
# # 			&printLog(2, "KEY: $key\tKEYS: $WCkeyS\tCOUNT: $count\tGC: $gc\n");
# # 			for (my $IDid = 0; $IDid < @pos; $IDid++)
# # 			{
# # 					(my $ID, my $sPos) = split(",", $pos[$IDid]);
# # 					$ID = $idKeyRev[$ID];
# # 					$poses   .= "[$ID,$sPos]";
# # 					$lastPos  = $sPos;
# # 					&printLog(2,"\tID: $ID\tSPOS: $sPos\n");
# # 			}
# # 			&printLog(2, "\n\n");
# # 		}
# 
# 		if ($keyType == 0) # lig
# 		{
# 			print WCFILE2 $WCkeyS . "\n";
# 			$countDBLig++;
# 		}
# 		elsif ($keyType == 1) # m13
# 		{
# 			print WCFILE3 $WCkeyS . "\n";
# 			$countDBM13++;
# 
# 			foreach my $lkey (@{$db[$key][6]})
# 			{
# 				my $allSeq = &digit2dna($db[$lkey][1]) . &digit2dna($WCkeyS);
# 				my $allGC  = &countGC($allSeq);
# 				my $allTm  = &tm($allSeq, $allGC);
# 				$countDB++;
# 				print WCFILE1  "$allSeq\t$gc\t$tm\n";
# 			}
# 
# 		}
# 
# # 			print"$keyS (" . length($keyS) . ")\n$ligSeq (" . length($ligSeq) . ")\n" . " "x($point) . "$m13Seq (" . length($m13Seq) . ")\n\n";
# 
# 	} #end for my key
# 
# 	close WCFILE3;
# 	close WCFILE2;
# 	close WCFILE1;
# 	&printLog(0, "\t$countDB UNIQUE PROBES EXPORTED\n");
# 	&printLog(0, "\t$countDBLig UNIQUE LIG PROBES EXPORTED\n");
# 	&printLog(0, "\t$countDBM13 UNIQUE M13 PROBES EXPORTED\n");
# }
# 
# sub mkDb2
# {
# 	$MKDBfile     = $_[0];
# 	$MKDBID       = $_[1];
# 	$MKDBligStart = $_[2];
# 	$MKDBligSeq   = $_[3];
# 	$MKDBligGC    = $_[4];
# 	$MKDBligTm    = $_[5];
# 	$MKDBm13Start = $_[6];
# 	$MKDBm13Seq   = $_[7];
# 	$MKDBm13GC    = $_[8];
# 	$MKDBm13Tm    = $_[9];
# # 	$MKDBallGC    = $_[10];
# # 	$MKDBallTm    = $_[11];
# 
# # 	open OUTFILE,  ">>$outdir/$file.wc2"     or die "COULD NOT OPEN $file.wc2";
# # 	open OUTFILE2, ">>$outdir/$file.lig.wc2" or die "COULD NOT OPEN $file.lig.wc2";
# # 	open OUTFILE3, ">>$outdir/$file.m13.wc2" or die "COULD NOT OPEN $file.m13.wc2";
# 
# 	if ( ! defined $MKDBligStart ) {die "ligStart not defined: $MKDBfile $MKDBID $MKDBligSeq"};
# 	if ( ! defined $MKDBm13Start ) {die "m13Start not defined: $MKDBfile $MKDBID $MKDBm13Seq"};
# 
# # 	print "\t\tMAKING FRAGMENTS FOR $file " . $idKeyRev[$ID] . " [$ID] (" . length($subSeq) . "bp) POS $sPos\n";
# #   	print "\t\t$subSeq (" . length($subSeq) . ")\n";
# 
# 	my $id   = 0;
# 	my $lkey = 0;
# 	my $mkey = 0;
# 	my $kkey = 0;
# 
# 	if ($makeHash)
# 	{
# # 		print "\t\tMAKING HASH\n";
# 
# 		if (defined $seqKey{$MKDBligSeq})
# 		{
# 			$lkey = $seqKey{$MKDBligSeq};
# # 			push(@{$db[$lkey][5]}, "$MKDBID,$MKDBligStart");
# # 			print "APPENDING LKEY OCCURENCE: $MKDBligSeq [$lkey]\t$MKDBID\t$MKDBligStart\n";
# 		}
# 		else
# 		{
# 			$lkey                = @db;
# 			$seqKey{$MKDBligSeq} = $lkey;
# # 			$seqKeyRev[$lkey]    = $MKDBligSeq;
# 			$db[$lkey][0] = $MKDBligSeq;
# 			$db[$lkey][1] = 0;
# 			$db[$lkey][2]++;
# 			$db[$lkey][3] = $MKDBligGC;
# 			$db[$lkey][4] = $MKDBligTm;
# # 			push(@{$db[$lkey][5]}, "$MKDBID,$MKDBligStart");
# # 			push(@{$db[$lkey][6]}, $mkey);
# 			
# # 			print "ADDING NEW LKEY: $MKDBligSeq [$lkey]\t$MKDBligGC\t$MKDBligTm\t$MKDBID\t$MKDBligStart\n";
# 		}
# 
# 
# 
# 
# 		if (defined $seqKey{$MKDBm13Seq})
# 		{
# 			$mkey = $seqKey{$MKDBm13Seq};
# # 			print "APPENDING MKEY OCCURENCE: $MKDBm13Seq [$mkey]\t$MKDBID\t$MKDBm13Start\n";
# # 			push(@{$db[$mkey][5]}, "$MKDBID,$MKDBm13Start");
# 		}
# 		else
# 		{
# 			$mkey                = @db;
# 			$seqKey{$MKDBm13Seq} = $mkey;
# # 			$seqKeyRev[$mkey]    = $MKDBm13Seq;
# 			$db[$mkey][0] = $MKDBm13Seq;
# 			$db[$mkey][1] = 1;
# 			$db[$mkey][2]++;
# 			$db[$mkey][3] = $MKDBm13GC;
# 			$db[$mkey][4] = $MKDBm13Tm;
# # 			push(@{$db[$mkey][5]}, "$MKDBID,$MKDBm13Start");
# # 			$db[$mkey][5]{"$MKDBID,$MKDBm13Start"} = 1;
#  			push(@{$db[$mkey][6]}, $lkey);
# 
# # 			print "ADDING NEW MKEY: $MKDBm13Seq [$mkey]\t$MKDBm13GC\t$MKDBm13Tm\t$MKDBID\t$MKDBm13Start\n";
# 		}
# 
# 
# 
# # 		if (defined $seqKey{"k$lkey$mkey"})
# # 		{
# # 			$kkey = $seqKey{"k$lkey$mkey"};
# # # 			push(@{$db[$lkey][5]}, "$MKDBID,$MKDBligStart");
# # # 			print "APPENDING KKEY OCCURENCE: $MKDBligSeq$MKDBm13Seq [$lkey $mkey]\t$MKDBID\t$MKDBligStart\t$MKDBm13Start\n";
# # 		}
# # 		else
# # 		{
# # 			$kkey                  = @db;
# # 			$seqKey{"k$lkey$mkey"} = $kkey;
# # # 			$seqKeyRev[$lkey]    = $MKDBligSeq;
# # 			$db[$kkey][0] = "$lkey,$mkey";
# # 			$db[$kkey][1] = 2;
# # 			$db[$kkey][2]++;
# # 			$db[$kkey][3] = $MKDBallGC;
# # 			$db[$kkey][4] = $MKDBallTm;
# # 			push(@{$db[$kkey][5]}, "$MKDBID,$MKDBligStart;$MKDBm13Start");
# # 
# # # 			print "ADDING NEW KKEY: $MKDBligSeq$MKDBm13Seq [$lkey $mkey]\t$MKDBallGC\t$MKDBallTm\t$MKDBID\n";
# # 		}
# 
# 
# 
# 	} #end if makehash
# # 	print OUTFILE  $idKeyRev[$ID] . "\t$ligSeq$m13Seq\t[$ligGC,$m13GC,$allGC]\t[$ligTm,$m13Tm,$allTm]\t[$ligStart,$m13Start]\n";
# # 	print OUTFILE2 $idKeyRev[$ID] . "\t$ligSeq\t$ligGC\t$ligTm\t$ligStart\n";
# # 	print OUTFILE3 $idKeyRev[$ID] . "\t$m13Seq\t$m13GC\t$m13Tm\t$m13Start\n";
# # 
# # 	close OUTFILE;
# # 	close OUTFILE2;
# # 	close OUTFILE3;
# }


# my $MKDBfile;
# my $MKDBID;
# my $MKDBligStart;
# my $MKDBligSeq;
# my $MKDBligGC;
# my $MKDBligTm;
# my $MKDBm13Start;
# my $MKDBm13Seq;
# my $MKDBm13GC;
# my $MKDBm13Tm;
# my $MKDBallGC;
# my $MKDBallTm;
# my $MKDBsubSeq;
# my $MKDBallSeq;


# sub mkDb
# {
# 	$MKDBfile     = $_[0];
# 	$MKDBID       = $_[1];
# 	$MKDBligStart = $_[2];
# 	$MKDBligSeq   = &dna2digit($_[3]);
# 	$MKDBligGC    = $_[4];
# 	$MKDBligTm    = $_[5];
# 	$MKDBm13Start = $_[6];
# 	$MKDBm13Seq   = &dna2digit($_[7]);
# 	$MKDBm13GC    = $_[8];
# 	$MKDBm13Tm    = $_[9];
# 	$MKDBallSeq   = &dna2digit($_[10]);
# 	$MKDBallGC    = $_[11];
# 	$MKDBallTm    = $_[12];
# 
# 	if ( ! defined $MKDBligStart ) {die "ligStart not defined: $MKDBfile $MKDBID $MKDBligSeq"};
# 	if ( ! defined $MKDBm13Start ) {die "m13Start not defined: $MKDBfile $MKDBID $MKDBm13Seq"};
# 
# 	my $id   = 0;
# 	my $lkey = 0;
# 	my $mkey = 0;
# 	my $kkey = 0;
# 
# 		if ( ! (defined $seqKey{$MKDBligSeq}))
# 		{
# 			$seqKey{$MKDBligSeq} = $lkey;
# # 			print "ADDING NEW LKEY: $MKDBligSeq [$lkey]\t$MKDBligGC\t$MKDBligTm\t$MKDBID\t$MKDBligStart\n";
# 			print WCFILE2 $MKDBligSeq . "\n";
# 			$countDBLig++;
# 		}
# 
# 
# 		if ( !(defined $seqKey{$MKDBm13Seq}))
# 		{
# 			$seqKey{$MKDBm13Seq} = $mkey;
# # 			print "ADDING NEW MKEY: $MKDBm13Seq [$mkey]\t$MKDBm13GC\t$MKDBm13Tm\t$MKDBID\t$MKDBm13Start\n";
# 			print WCFILE3 $MKDBm13Seq . "\n";
# 			$countDBM13++;
# 		}
# 
# 		if ( ! (defined $seqKey{"k$MKDBallSeq"}))
# 		{
# 			$seqKey{"k$MKDBallSeq"} = $kkey;
# 			$countDB++;
# 			print WCFILE4 $MKDBallSeq . "\n";
# 			print WCFILE1 &digit2dna($MKDBallSeq) . "\t[$MKDBligGC,$MKDBm13GC,$MKDBallGC]\t[$MKDBligTm,$MKDBm13Tm,$MKDBallTm]\t[$MKDBligStart,$MKDBm13Start,$MKDBID]\n";
# 		}
# }
