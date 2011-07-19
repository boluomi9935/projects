#!/usr/bin/perl -w
use strict;
use lib "./filters";
use dnaCodeOO;
use fastaOO;
use loadconf;
use mlpaOO;
my %pref = &loadconf::loadConf;

use Storable;
use Data::Dumper;

#list *.shared.gz
#read each line
#convert key to sequence
#convert values to filenames
#load filenames
#search for sequence
#export
#    filename\tchrom1[start1-end1,start2-end2];chrom2[start3-start4]

my $dnaCode     = dnaCodeOO->new();
my $files       = &getFiles(undef,"shared.gz");
my $taxFile     = '/home/saulo/Desktop/rolf/input/taxonomy.idx';
my $inputFolder = '/home/saulo/Desktop/rolf/input/';
my $outputFile1 = 'mapping_byFrag.txt';
my $outputFile2 = 'mapping_byPos.txt';
my $outputFile3 = 'mapping_byPos.xml';
my $fragLen     = 24;
my ($taxonomy, $taxIds) = &getTaxonomy($taxFile);

my %hash;
my %frags;
my @frags;
my %whoms;
my @whoms;
my %byPos;

my $notSkip = 0;

if ( ! -f "exportPositions_Hhash.dump"  ) { $notSkip++ };
if ( ! -f "exportPositions_Hfrags.dump" ) { $notSkip++ };
if ( ! -f "exportPositions_Afrags.dump" ) { $notSkip++ };
if ( ! -f "exportPositions_Hwhoms.dump" ) { $notSkip++ };
if ( ! -f "exportPositions_Awhoms.dump" ) { $notSkip++ };
if ( ! -f "exportPositions_HbyPos.dump" ) { $notSkip++ };

if ( $notSkip )
{
	&readFiles();
	&acquirePositions();
	&exportByFrag();
	save(\%hash,  "exportPositions_Hhash.dump" );
	save(\%frags, "exportPositions_Hfrags.dump");
	save(\@frags, "exportPositions_Afrags.dump");
	save(\%whoms, "exportPositions_Hwhoms.dump");
	save(\@whoms, "exportPositions_Awhoms.dump");
	save(\%byPos, "exportPositions_HbyPos.dump");
	&exportByPos();
}
else
{
	load(\%hash,  "exportPositions_Hhash.dump" );
	load(\%frags, "exportPositions_Hfrags.dump");
	load(\@frags, "exportPositions_Afrags.dump");
	load(\%whoms, "exportPositions_Hwhoms.dump");
	load(\@whoms, "exportPositions_Awhoms.dump");
	load(\%byPos, "exportPositions_HbyPos.dump");
	&exportByPos();
}


sub readFiles
{
	foreach my $file (keys %{$files})
	{
		print "READING SHARED FILE $file\n";
		open(EXTRACTOR, "gunzip -cd  $file 2>&1|") or die "FAILED TO EXECUTE FIRST: $!";
		while ( my $line = <EXTRACTOR> )
		{
			chomp $line;
			#print $line, "\n";
			
			if ($line =~ /(.*)\t(.*)/)
			{
				my $frag    = $1;
				my $valu    = $2;
				my @values  = split(",", $valu);
				my $fragNum = 0;
				
				if ( exists $frags{$frag} )
				{
					$fragNum = $frags{$frag};
				}
				else
				{
					$frags{$frag}    = scalar(keys %frags);
					$fragNum         = $frags{$frag};
					$frags[$fragNum] = uc($dnaCode->digit2dna($frag));
				}
	
				my $whomNum = 0;
				if ( exists $whoms{$valu} )
				{
					$whomNum = $whoms{$valu};
				}
				else
				{
					$whoms{$valu}    = scalar( keys %whoms );
					$whomNum         = $whoms{$valu};
					$whoms[$whomNum] = $valu;
				}
	
				foreach my $value (@values)
				{
					$hash{$value}{$fragNum}[0] = ();    # pos
					push(@{$hash{$value}{$fragNum}[1]}, $whomNum); # whom
					push(@{$hash{$value}{$fragNum}[2]}, $file); # whom
				}
			}
		}
		close EXTRACTOR;
	}
	
	print "THERE ARE ", scalar(keys %whoms), " WHOMS\n";
	print "THERE ARE ", scalar(keys %frags), " FRAGS\n";
	print "THERE ARE ", scalar(keys %hash),  " ORGANISMS\n";
	print "\n\n";
}


sub acquirePositions
{
	foreach my $id ( keys %hash )
	{
		print	"\tORG ID: ", $id,
				" VARS : ", scalar(@{$taxIds->[$id]}),
				" FRAGS: ", scalar(keys %{$hash{$id}}),
				" FILES:\n";
				
		map { print "\t\t$_\n" } @{$taxIds->[$id]};
		
		#print "\n";
		
		my %frags2Find;
		
		foreach my $fragNum ( sort {$a <=> $b } keys %{$hash{$id}} )
		{
			my @whomNums  = @{$hash{$id}{$fragNum}[1]};
			my @whomFiles = @{$hash{$id}{$fragNum}[2]};
			
			my $fragName = $frags[$fragNum];
			#print "\tFRAG #", $fragNum, ": ", $fragName, " [",length($fragName)," bp]\n";
			
			$frags2Find{$fragName} = $fragNum;
			
			for (my $w = 0; $w < @whomNums; $w++)
			{
				my $whomFile = $whomFiles[$w];
				my $whomNum  = $whomNums[$w];
				my $whomName = $whoms[$whomNum];
	
				#print "\t\tWHOM #", $whomNum, ": ", $whomName, " FILE ",$whomFile, "\n";
			}
			#print "\n";
		}
		print "\t\tTHERE ARE ",scalar(keys %frags2Find)," FRAGMENTS TO BE FOUND\n";		
		
		
		
		print "\t\tACQUIRING POSITIONS:\n";
		for (my $var = 0; $var < @{$taxIds->[$id]}; $var++ )
		{
			my $file = $taxIds->[$id][$var];
			print "\t\tFILE $inputFolder/$file [ID $id VAR $var]\n";
			die "FILE $inputFolder/$file NOT FOUND" if ( ! -f "$inputFolder/$file" );
			
			open FASTA, "<$inputFolder/$file" or die "COULD NOT OPEN FILE $inputFolder/$file: $!";
			my $chromCount  = -1;
			my $pos = 0;
			my $seq = '';
			my %foundFrags;
			my $found = 0;

			while (my $line = <FASTA>)
			{
				chomp $line;
				#print $line, "\n";
				
				if (substr($line, 0, 1) eq ">")
				{
					$chromCount++;
					$pos = 0;
					$seq = '';
				}
				else
				{
					$seq .= uc($line);
					while (length($seq) >= $fragLen)
					{
						my $piece = substr($seq, 0, $fragLen);
						#my $piecerc = reverse($piece);
						#$piecerc =~ tr/ACGT/TGCA/; 

						#print "TESTING $piece [",length($piece)," bp] SEQ $seq [",length($seq)," bp]\n";
						$seq = substr($seq, 1);
						
						if ( exists $frags2Find{$piece} )
						{
							#print "\tFOUND [",$found++,"] $piece\n";
							my $fragNum = $frags2Find{$piece};
							$foundFrags{$piece}++;
							push(@{$hash{$id}{$fragNum}[0][$var][$chromCount]}, $pos);    # pos
						}
						
						#if ( exists $frags2Find{$piecerc} )
						#{
						#	print "\tFOUND RC [",$found++,"] $piece\n";
						#	my $fragNum = $frags2Find{$piecerc};
						#	$foundFrags{$piecerc}++;
						#	push(@{$hash{$id}{$fragNum}[0][$var][$chromCount]}, $pos);    # pos
						#}

						$pos++;
					}
				}
			}
			close FASTA;
			
			print "\tFILE $file HAS $chromCount CHROMOSSOMES\n";
			
			if (scalar(keys %frags2Find) != scalar(keys %foundFrags))
			{
				print "YOU SHOULD HAVE FOUND ", scalar(keys %frags2Find), " ";
				print "BUT COULD FIND ONLY ", scalar(keys %foundFrags), "\n";
				
				foreach my $key (keys %frags2Find)
				{
					if ( ! exists $foundFrags{$key})
					{
						my $value = $frags2Find{$key};
						my @whomFiles = @{$hash{$id}{$value}[2]};
						print $key, " [$value] FROM " ,join(";", @whomFiles), " NOT FOUND\n";
					}
				}
				
				die "OOPS" ;
			}
		}
		print	"\tORG ID: ", $id, " FINISHED\n\n";
	}
}


sub exportByFrag
{
	open OUT, ">$outputFile1" or die "COULD NOT OPEN $outputFile1: $!";
	foreach my $orgId (sort keys %hash)
	{
		print "EXPORTING ORG ID: ", $orgId, "\n";
		my $frags = $hash{$orgId};
		foreach my $fragNum (sort {$a <=> $b} keys %{$frags})
		{
			my $vars = $frags->{$fragNum}[0];
			next if ( ! defined $vars );
			#print "\tFRAG #", $fragNum, ": ", $frags[$fragNum], "\n";
	
			for (my $var = 0; $var < @{$vars}; $var++)
			{
				my $chroms = $vars->[$var];
				next if ( ! defined $chroms );
				#print "\t\tVAR: ", $var, "\n";
	
				for (my $chrom = 0; $chrom < @{$chroms}; $chrom++)
				{
					my $poses = $chroms->[$chrom];
					next if ( ! defined $poses );
					#print "\t\t\tCHROM #", $chrom, "\n";
					foreach my $pos (@{$poses})
					{
						#print "\t\t\t\tPOS: ",$pos,"\n";
						my @whomFiles = @{$frags->{$fragNum}[2]};
						my @whomNums  = @{$frags->{$fragNum}[1]};
						$byPos{$orgId}[$var][$chrom][$pos][0]++;
						$byPos{$orgId}[$var][$chrom][$pos][1] = $frags[$fragNum];
						$byPos{$orgId}[$var][$chrom][$pos][2] = \@whomNums;
						$byPos{$orgId}[$var][$chrom][$pos][3] = \@whomFiles;
	
						my %sW;
						map { if ( ! exists $sW{$_} ) { $sW{$_} = 1 }; } @whomNums;
						@whomNums = map { $_ = $whoms[$_]; } keys %sW;
						
						my $line = sprintf("%06d\t%02d\t%04d\t%09d\t%09d\t%".$fragLen."s\t%s\t%s\n",
						$orgId, $var, $chrom, $pos, ($pos+$fragLen),$frags[$fragNum], 
						join(",", @whomNums),
						join(",", @whomFiles));
						print OUT $line;
						#push(@{$hash{$id}{$fragNum}[0][$var][$chromCount]}, $pos);    # pos
					}
				}
			}
		}
	}
	close OUT;
}


sub exportByPos
{
	open OUT, ">$outputFile2" or die "COULD NOT OPEN $outputFile2: $!";
	open XML, ">$outputFile3" or die "COULD NOT OPEN $outputFile3: $!";
	
	foreach my $orgId (sort keys %byPos)
	{
		#print "EXPORTING ORG ID: ", $orgId, "\n";
		my $vars = $byPos{$orgId};
		
		for (my $var = 0; $var < @{$vars}; $var++)
		{
			my $chroms = $vars->[$var];
			next if ( ! defined $chroms );
			#print "\tVAR: ", $var, " CHROM: ";
	
			my $file = $taxIds->[$orgId][$var];
			print "\t\tFILE $inputFolder/$file [$orgId] VAR $var\n";
			
			die "FILE $inputFolder/$file NOT FOUND" if ( ! -f "$inputFolder/$file" );
			my $fasta = fastaOO->new("$inputFolder/$file");
	
			my $chromCount = 0;
	
			for (my $chrom = 0; $chrom < @{$chroms}; $chrom++)
			{
				my $poses = $chroms->[$chrom];
				
				next if ( ! defined $poses );
				#print "$chrom, ";
				#print "\t\t\tPOS\n";
				for (my $pos = 0; $pos < @{$poses}; $pos++)
				{
					next if ( ! defined $poses->[$pos]);
					my $count     = $poses->[$pos][0];
					my $frag      = $poses->[$pos][1];
					my $whomNums  = $poses->[$pos][2];
					my $whomFiles = $poses->[$pos][3];
					
					my $newPos = $pos - 50;
					if ($newPos < 0) { $newPos = 0; };
					my $posDiff = $pos - $newPos;
					my $newLen  = $posDiff + $fragLen + 50;
					
					my $seq = $fasta->getPos($chrom, $newPos, $newLen);
					
					if (uc($frag) ne uc(substr($seq, $posDiff, $fragLen)))
					{
						print "FILE $inputFolder/$file CHROM $chrom POS $pos NEWPOS $newPos POSDIFF $posDiff",
							  " SEQ ",uc(substr($seq, $posDiff, $fragLen)),
							  " FRAG $frag",
							  " FULL SEQ $seq [",length($seq),"]\n";
						die;
					}
					
					my $next     = $pos + 1;
					my $lastPos  = $pos;
					my $lastWhom = join("", @{$whomNums});
					
					for ($next = $pos + 1; $next < @{$poses}; $next++)
					{
						#print "\t\t\t\t\tNEXT: $next LASTPOS: $lastPos\n";
						if ( $next >= ($lastPos + $fragLen) )
						{ $lastPos = $next-1; last; };
						
						if ( defined $poses->[$next] )
						{
							#print "\t"x6, "NEW LASTPOS: $next\n";
							my $currentWhom = join("",@{$poses->[$next][2]});
							if ($currentWhom eq $lastWhom)
							{
								$lastPos = $next;
							}
							else
							{
								$lastWhom = $currentWhom;
								$next -= 1;
								last;
							}
						}
					}

					#print "STARTPOS\tENDPOS\tCOUNT\tFRAG\tWHOMNUMS\tWHOMFILES\n";
					#162425	00	0031	000128510	000128531	CGGCGTGTGGCTTAAGTACGGCTG	33178,5061,162425,5057,5085,5062,5059	147545.wc.sort.ag.shared.gz,5042.wc.sort.ag.shared.gz,28568.wc.sort.ag.shared.gz
					#print $line;
					my $line =  sprintf("%06d\t%02d\t%04d\t%09d\t%09d\t%".$fragLen."s\t%s\t%s\n",
								$orgId,$var,$chrom,$pos,$next,$frag,
								join(",", @{$whomNums}),
								join(",", @{$whomFiles}));
								
								
					my $mlpa = mlpaOO->new(\%pref, 0);
					my @probe;
					my $ite;
					my $lCountValAll;
					my $centimo;
					my $maxLigLen;
					($ite, $lCountValAll, $centimo, $maxLigLen) = $mlpa->act(\@probe, $seq, $newPos);

					#print "ITE $ite COUNTVAL $lCountValAll CENTIMO $centimo MAXLIGLEN $maxLigLen PROBES ",length(@probe)," FRAG $frag SEQ $seq\n";
#0
#		0	4
#		1	34
#		2	70
#		3	F
#		4	jlWL>H[Okn
#		5	53
#		6	78
#		7	nVVUq5MR]z2Vg
#		8	51
#		9	82
#		10	jlWL>H[OknnVVUq5MR]z2Vg
#		11	52
#		12	91
#		13	]Yo5ewct

					

					for (my $p = 0; $p < @probe; $p++)
					{
						my $lProbe = $probe[$p];
						map { print $_,"\t"; } @$lProbe;						print "\n";
					}
					print "\n";
								
					print OUT $line;
					#print "$pos-$next;";
					$pos = $next;
				}
			}
			$fasta->DESTROY();
			#print "\n";
		}
	}
	close XML;
	close OUT;
}



	
sub getFiles
{
	my $prefix = $_[0] || "";
	my $sufix  = $_[1] || "";
	
	print "\t\t\tGETTING FILE :: PREFIX: $prefix SUFIX: $sufix";
	
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
		if ( ! -l $infiles[$f] )
		{
			$files{$infiles[$f]} = $insizes[$f];
		}
	}
	print " RESULT: ", scalar(keys %files), "\n";
	return \%files;
}


sub getTaxonomy
{
	my $file = $_[0];
	my %taxonomy;
	my @taxIds;
	print "LOADING TAXONOMIC FILE $file...";

	open FILE, "<$file" or die "COULD NOT OPEN FASTA FILE $file: $!\n";
	my $count      = 0;
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
					$taxIds[$taxID][$variant] = $fasta;
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
	return \%taxonomy, \@taxIds;
}







sub load
{
    my $ref  = $_[0];
	my $file = $_[1];
	print "\t\tLOADING $file\n";
	#	my $name = $_[1];

	die "DIED: FILE $file NOT FOUND" if ( ! -f $file );

    if (ref($ref) eq "HASH")
	{
            %{$ref} = %{retrieve("$file")} or die "DIED: COULD NOT RETRIEVE FILE $file: $!";
    }
	elsif (ref($ref) eq "ARRAY")
    {
            @{$ref} = @{retrieve("$file")} or die "DIED: COULD NOT RETRIEVE FILE $file: $!";;
    };

	#	return $ref;
    #%database = %{retrieve($prefix."_".$name."_store.dump")};
};

sub save
{
    my $ref  = $_[0];
    my $file = $_[1];
	print "\t\tSAVING $file\n";
    store $ref, "$file" or die "COULD NOT SAVE DUMP FILE $file: $!";
#	return $ref;
};

1;
