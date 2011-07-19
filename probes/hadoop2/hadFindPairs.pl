#!/usr/bin/perl -w
use strict;
use lib "./filters";
use toolsOO;

my $minLength         =  70;
my $maxLength         = 330;
my $totalLines        = 0;
my $indirTaxonomyFile = "/home/saulo/Desktop/rolf/input/taxonomy.idx";
#my $file             = '/home/saulo/Desktop/rolf/rolf2/taxonomy.verbose.tab';

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!!!!!!!!!!!! CHECK COMPLEMENTARITY !!!!!!!!!!!!!!!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


die "WRONG NUMBER OF INPUT" if (@ARGV < 2);

my $inFile = $ARGV[0];
my @pairs  = @ARGV[1 .. (@ARGV - 1)];

my %pairs;
my %id2Tax;
my %taxonomy;
my %allValues;
my %elected;
my %byProbe;
my $XMLPROBEHEADER;
my $XMLPROBETAIL;
my $XMLORGHEADER;
my $XMLORGTAIL;
my $totalOverlaps = 0;
my $totalOrgs     = 0;
my $totalFwds     = 0;

#$allValues[$orgId][$var][$chrom][$start][0][$frame][0]   = \$seq;
#$allValues[$orgId][$var][$chrom][$start][0][$frame][1] = $start;
#$allValues[$orgId][$var][$chrom][$start][0][$frame][2] = $frame;

#$allValues[$orgId][$var][$chrom][$start][1][nn] = FWD INFO
#push(@{$poses->[$tPos][1]}, $fwd);
#$allValues[$orgId][$var][$chrom][$start][2][nn] = REV INFO
#push(@{$poses->[$tPos][2]}, $rev);

#$elected[$org][$var][$chrom][0] = fwd probe info
#$elected[$org][$var][$chrom][1] = rev probe info
#push(@{$elected[$org][$var][$chrom]},[$fwd, $rev]);


if ( ! defined $inFile ) { print STDERR time, " NO INFILE :: NO INPUT FILE DEFINED";    die; };
if ( ! -f      $inFile ) { print STDERR time, " $inFile :: FILE $inFile DOESNT EXISTS"; die; };
if ( !         @pairs  ) { print STDERR time, " $inFile :: NO PAIRS";                   die; };

my $tools           = toolsOO->new();
my $logFile         = $inFile . ".log";
my $outFileOrgTab   = $inFile . ".org.pairs.tab";
my $outFileOrgXml   = $inFile . ".org.pairs.xml";
my $outFileProTab   = $inFile . ".probe.pairs.tab";
my $outFileProXml   = $inFile . ".probe.pairs.xml";
my $outFileFastaFwd = $inFile . ".probe.pairs.fwd.fasta";
my $outFileFastaRev = $inFile . ".probe.pairs.rev.fasta";


open STDERR, ">$logFile"     or print STDERR time, " $inFile :: COULD NOT OPEN $logFile    : $!" && die;

my $pairStr = '';
map { $_ =~ s/\\//; $pairs{$_} = 1; $pairStr .= " PAIR $_;" } @pairs;
print STDERR time, " $inFile :: PAIRS : $pairStr\n";


my $totalPairs    = scalar(keys %pairs);
print STDERR time, " $inFile :: TOTAL PAIRS : $totalPairs\n";


&getTaxonomy($indirTaxonomyFile, \%taxonomy);
my %tax;
foreach my $fileName (sort keys %taxonomy)
{
	my $taxId = $taxonomy{$fileName}[0];
	my $var   = $taxonomy{$fileName}[0];
	if (exists $pairs{$taxId.".".$var})
	{
		$tax{$taxId.".".$var} = $fileName;
	}
}


&loadXMLHeader();



print STDERR time, " $inFile :: READING INPUT FILE...\n";
open INFILE,   "<$inFile"   or print STDERR time, " $inFile :: COULD NOT OPEN $inFile   : $!\n" && die;
while (my $line = <INFILE>)
{
	$totalLines++;
	chomp $line;
	(my $seq, my $pos) = split("\t", $line);
	if (( ! defined $seq ) || ( ! defined $pos )) { print STDERR time, " $inFile :: NO SPLIT: $line \n"; die; };
	&parseValuePCR($seq, $pos);
}
close INFILE;
my $totalValues = scalar(keys %allValues);
print STDERR time, " $inFile :: READING INPUT FILE COMPLETED. $totalLines LINES AND $totalValues VALUES RETRIEVED\n";


&calculateOverlaps() if ($totalValues > 0);
if ($totalOverlaps)
{
	&byOrg()
}

if ($totalOrgs)
{
	&byFwd();
}
else
{
	unlink($outFileOrgTab);
	unlink($outFileOrgXml);
}

if ( $totalFwds )
{
	&genFasta();
}
else
{
	unlink($outFileProTab);
	unlink($outFileProXml);
}

print STDERR time, " $inFile :: PROGRAM COMPLETED\n";
close STDERR;



#array[org][var][chrom][pos][0][frame F1 R0] = line / lineNum
#$allValues{$orgId}[$var][$chrom]{$start}[0][$frame][0] = \$seq;
sub calculateOverlaps
{
	print STDERR time, " $inFile :: CALCULATING OVERLAPS...\n";
	my %oSeenOrgs;
	foreach my $org (sort {$a <=> $b} keys %allValues)
	{
		my $vars = $allValues{$org};
		next if ( ! defined $vars );
		for (my $var = 0; $var < @{$vars}; $var++)
		{
			next if  ( ! exists $pairs{$org.".".$var} );
			my $chroms = $vars->[$var];
			next if ( ! defined $chroms );
			for (my $chrom = 0; $chrom < @{$chroms}; $chrom++)
			{
				my $poses = $chroms->[$chrom];
				next if ( ! defined $poses );
				my $totalPos = scalar(keys %{$poses});
				my @overlaps;
				foreach my $pos (sort {$a <=> $b} keys %{$poses})
				{
					my $seqInfo = $poses->{$pos};
					next if ( ! defined $seqInfo);

					my $rev     = $seqInfo->[0];
					my $fwd 	= $seqInfo->[1];

					my $primerF = $fwd->[0]; #ref seq
					my $primerR = $rev->[0]; #ref seq

					#$allValues{$orgId}[$var][$chrom]{$start}[$frame][0] = \$seq;
					#printf "ORG %06d VAR %d CHROM %04d POS %09d PRIMERF \"%30s\" PRIMERR \"%30s\"\n", $org,$var,$chrom,$pos, ($primerF ? ${$primerF} : " "x30),($primerR ? ${$primerR} : " "x30);

					if ($primerF)
					{
						#print "FWD\n";
						my $ePos = ($pos + $maxLength);
						$ePos = $ePos > $totalPos ? $totalPos : $ePos;

						for (my $tPos = $pos; $tPos <= $ePos; $tPos++)
						{
							$overlaps[1][$tPos]{$pos} = 1;

							if (defined %{$overlaps[0][$tPos]})
							{
								foreach my $nfoPos (keys %{$overlaps[0][$tPos]})
								{
									my $nfo = $poses->{$nfoPos}[0];
									$oSeenOrgs{$org.".".$var} = 1;
									$elected{$org}[$var][$chrom]{$pos}{$nfoPos} = [$nfo, $fwd];
									$totalOverlaps++;
								}
							}
						}
					}
					elsif ($primerR)
					{
						my $sPos = ($pos - $maxLength) < 0 ?  0 : ($pos - $maxLength);

						for (my $tPos = $sPos; $tPos <= $pos; $tPos++)
						{
							$overlaps[0][$tPos]{$pos} = 1;

							if (defined %{$overlaps[1][$tPos]})
							{
								foreach my $nfoPos (keys %{$overlaps[1][$tPos]})
								{
									my $nfo = $poses->{$nfoPos}[1];
									$oSeenOrgs{$org.".".$var} = 1;
									$elected{$org}[$var][$chrom]{$nfoPos}{$pos} = [$rev, $nfo];
									$totalOverlaps++;
								}
							}
						}
					}
				}
			}
		}
	}
	print STDERR time, " $inFile :: CALCULATING OVERLAPS COMPLETED. $totalOverlaps OVERLAPS EXPORTED\n";
	undef %allValues;
}


sub byOrg
{
	print STDERR time, " $inFile :: GENERATING PROBES LIST [BY ORGANISM]\n";
	open  OUTFILEORGTAB,  ">$outFileOrgTab"  or print STDERR time, " $inFile :: COULD NOT OPEN $outFileOrgTab : $!" && die;
	open  OUTFILEORGXML,  ">$outFileOrgXml"  or print STDERR time, " $inFile :: COULD NOT OPEN $outFileOrgXml : $!" && die;

	print OUTFILEORGXML $XMLORGHEADER;

	#$elected{$org}[$var][$chrom]{$nfoPos}{$pos} = [$nfo, $rev];
	foreach my $org (sort {$a <=> $b} keys %elected)
	{
		my $vars = $elected{$org};
		next if ( ! defined $vars );
		my $orgTxt;

		for (my $var = 0; $var < @{$vars}; $var++)
		{
			next if  ( ! exists $pairs{$org.".".$var} );
			my $chroms = $vars->[$var];
			next if ( ! defined $chroms );
			my $varTxt;
			for (my $chrom = 0; $chrom < @{$chroms}; $chrom++)
			{
				my $chromTxt;
				my $validP = 0;
				my $startPoses = $chroms->[$chrom];
				next if (! defined $startPoses );
				#print "CHROM $chrom\n";
				#$elected{$org}[$var][$chrom]{$nfoPos}{$pos} = [$rev, $nfo];
				foreach my $startPos (sort {$a <=> $b} keys %{$startPoses})
				{
					#print "  STARTPOS $startPos\n";
					my $fwdPos = $startPoses->{$startPos};
					foreach my $endPos (sort {$a <=> $b} keys %{$fwdPos})
					{
						#print "    END POS $endPos\n";
						my $pairs = $fwdPos->{$endPos};
						#next if ( ! defined $pairs );

						my $revInfo  = $pairs->[0];
						my $fwdInfo  = $pairs->[1];

						my $revPrimer = ${$revInfo->[0]}; #ref
						my $revStart  = $revInfo->[1];
						my $revFrame  = $revInfo->[2];

						my $fwdPrimer = ${$fwdInfo->[0]}; #ref
						my $fwdStart  = $fwdInfo->[1];
						my $fwdFrame  = $fwdInfo->[2];

						my $prodLength = ($revStart - $fwdStart);

						next if ($prodLength < $minLength);
						next if ($prodLength > $maxLength);

						next if ($tools->checkComplementarity($fwdPrimer, $revPrimer));
						my $fwdTm = $tools->tmPCR($fwdPrimer);
						my $revTm = $tools->tmPCR($revPrimer);
						next if ($fwdTm - $revTm > 6);
						next if ($revTm - $fwdTm > 6);

						#printf "      ORG %06d VAR %d CHROM %04d. FWD: SEQ \"%30s\" POS %09d FRAME %d REV: SEQ \"%30s\" POS %09d FRAME %d :: PCR PROD LENGTH: %d\n",
						#$org,$var,$chrom,$fwdPrimer, $fwdStart, $fwdFrame, $revPrimer, $revStart, $revFrame, $prodLength;

						print OUTFILEORGTAB $org,"\t",$var,"\t",$chrom,"\t",$fwdPrimer,"\t", $fwdStart,"\t", $fwdFrame, "\t",$revPrimer, "\t",$revStart, "\t",$revFrame, "\t",$prodLength, "\n";

						$validP++;
						$chromTxt .= "\t\t\t\t<pair id=\"$validP\">\n";

						$chromTxt .= "\t\t\t\t\t<fwdStart>   $fwdStart   </fwdStart>\n";
						$chromTxt .= "\t\t\t\t\t<fwdFrame>   $fwdFrame   </fwdFrame>\n";
						$chromTxt .= "\t\t\t\t\t<fwdSeq>     $fwdPrimer  </fwdSeq>\n";
						$chromTxt .= "\t\t\t\t\t<revStart>   $revStart   </revStart>\n";
						$chromTxt .= "\t\t\t\t\t<revFrame>   $revFrame   </revFrame>\n";
						$chromTxt .= "\t\t\t\t\t<revSeq>     $revPrimer  </revSeq>\n";
						$chromTxt .= "\t\t\t\t\t<prodLength> $prodLength </prodLength>\n";

						$chromTxt .=  "\t\t\t\t</pair>\n";
						$totalOrgs++;

						push(@{$byProbe{$fwdPrimer}{$revPrimer}{$org}[$var][$chrom]}, $pairs);
					}
				}
				$varTxt .= "\t\t\t<chrom id=\"$chrom\">\n$chromTxt\t\t\t</chrom>\n" if $chromTxt;
			}
			$orgTxt .= "\t\t<var id=\"$var\">\n$varTxt\t\t</var>\n" if $varTxt;
		}
		print OUTFILEORGXML "\t<org id=\"$org\">\n$orgTxt\t</org>\n" if $orgTxt;
	}
	undef %elected;
	print OUTFILEORGXML "</orgs>\n";

	close OUTFILEORGTAB;
	close OUTFILEORGXML;
	print STDERR time, " $inFile :: GENERATING PROBES LIST [BY ORGANISM] COMPLETED. $totalOrgs ORGS EXPORTED\n";
}







sub byFwd
{
	print STDERR time, " $inFile :: GENERATING PROBES LIST [BY PROBE]\n";
	open  OUTFILEPROTAB,  ">$outFileProTab"  or print STDERR time, " $inFile :: COULD NOT OPEN $outFileProTab : $!" && die;
	open  OUTFILEPROXML,  ">$outFileProXml"  or print STDERR time, " $inFile :: COULD NOT OPEN $outFileProXml : $!" && die;
	print OUTFILEPROXML "$XMLPROBEHEADER\n";

	my $xmlSummary = "
<!--	SUMMARY OF SPECIES FOUND	-->
\t<summary>\n";

	foreach my $fwd (sort keys %byProbe)
	{
		my $fwdTxt;
		my $fwdTxtTab;
		my %seenSpp;
		foreach my $rev (sort keys %{$byProbe{$fwd}})
		{
			my $revTxt;
			my $chroms = $byProbe{$fwd}{$rev};
			foreach my $org (sort {$a <=> $b} keys %{$chroms})
			{
				my $vars = $chroms->{$org};
				next if ( ! defined $vars );
				my $orgTxt;

				for (my $var = 0; $var < @{$vars}; $var++)
				{
					my $chroms = $vars->[$var];
					next if ( ! defined $chroms );
					my $varTxt;
					$seenSpp{$org.".".$var} = 1;

					for (my $chrom = 0; $chrom < @{$chroms}; $chrom++)
					{
						my $pairs = $chroms->[$chrom];
						next if ( ! defined $pairs );
						my $chromTxt;

						my $validP = 0;

						for (my $p = 0; $p < @{$pairs}; $p++)
						{
							my $revInfo   = $pairs->[$p][0];
							my $fwdInfo   = $pairs->[$p][1];

							my $fwdPrimer = ${$fwdInfo->[0]}; #ref
							my $fwdStart  = $fwdInfo->[1];
							my $fwdFrame  = $fwdInfo->[2];

							my $revPrimer = ${$revInfo->[0]}; #ref
							my $revStart  = $revInfo->[1];
							my $revFrame  = $revInfo->[2];

							my $prodLength = ($revStart - $fwdStart);

							#printf "FWD: SEQ \"%30s\" POS %09d FRAME %d REV: SEQ \"%30s\" POS %09d FRAME %d :: PCR PROD LENGTH: %d :: ORG %06d VAR %d CHROM %04d.  \n",
							#$fwdPrimer, $fwdStart, $fwdFrame, $revPrimer, $revStart, $revFrame, $prodLength, $org,$var,$chrom;

							$fwdTxtTab .= $fwdPrimer."\t". $fwdStart."\t". $fwdFrame. "\t".$revPrimer. "\t".$revStart. "\t".$revFrame. "\t".$prodLength."\t". $org."\t".$var."\t".$chrom."\n";

							$validP++;
							$chromTxt .= "\t"x7 . "<pos id=\"$validP\">\n";

							$chromTxt .= "\t"x8 . "<fwdStart>   $fwdStart   </fwdStart>\n";
							$chromTxt .= "\t"x8 . "<fwdFrame>   $fwdFrame   </fwdFrame>\n";
							$chromTxt .= "\t"x8 . "<fwdSeq>     $fwdPrimer  </fwdSeq>\n";
							$chromTxt .= "\t"x8 . "<revStart>   $revStart   </revStart>\n";
							$chromTxt .= "\t"x8 . "<revFrame>   $revFrame   </revFrame>\n";
							$chromTxt .= "\t"x8 . "<revSeq>     $revPrimer  </revSeq>\n";
							$chromTxt .= "\t"x8 . "<prodLength> $prodLength </prodLength>\n";

							$chromTxt .=  "\t"x7 . "</pos>\n";

						} #end foreach my pair
						$varTxt .= "\t"x6 . "<chrom id=\"$chrom\">\n$chromTxt". "\t"x6 ."</chrom>\n" if $chromTxt;
					} #end foreach my chrom
					$orgTxt .= "\t"x5 . "<var id=\"$var\">\n$varTxt". "\t"x5 ."</var>\n" if $varTxt;
				} # end foreach my car
				$revTxt .= "\t"x4 . "<org id=\"$org\">\n$orgTxt". "\t"x4 ."</org>\n" if $orgTxt;
			} #end foreach my org
			$fwdTxt .= "\t"x3 . "<rev id=\"$rev\">\n$revTxt". "\t"x3 ."</rev>\n" if $revTxt;
		} #end foreach my rev

		my $seenSpp = scalar(keys %seenSpp);
		if ($seenSpp == $totalPairs)
		{
			print OUTFILEPROXML "\t"x2 , "<fwd id=\"$fwd\">\n", $fwdTxt, "\t"x2 , "</fwd>\n";
			print OUTFILEPROTAB $fwdTxtTab;
			$totalFwds++;
			$xmlSummary .= "\t"x2 . "<fwd id=\"$fwd\">\n";
			foreach my $seenSpp (sort keys %seenSpp)
			{
				$xmlSummary .= "\t"x3 . "<org>$seenSpp</org>\n";
			}
			$xmlSummary .= "\t"x2 . "</fwd>\n";
		}
		else
		{
			print STDERR time, " $inFile :: SEQUENCE FWD $fwd APPEARS IN ONLY ", $seenSpp, " SPP WHEN ", $totalPairs, " SPP WAS EXPECTED\n";
		}
	}

	$xmlSummary .= "\t"x1 . "</summary>\n\n";

	print OUTFILEPROXML "\t"x1 . "</probes>\n\n\n";
	print OUTFILEPROXML $xmlSummary;
	print OUTFILEPROXML $XMLPROBETAIL;



	close OUTFILEPROTAB;
	close OUTFILEPROXML;
	print STDERR time, " $inFile :: GENERATING PROBES LIST [BY PROBE] COMPLETED. $totalFwds FWD PRIMERS EXPORTED\n";;
}



sub genFasta
{
	print STDERR time, " $inFile :: GENERATING FASTA FILE [BY PROBE]\n";

	my %seenSpp;
	foreach my $fwd (sort keys %byProbe)
	{
		$seenSpp{fwd}{$fwd} = 1;
		foreach my $rev (sort keys %{$byProbe{$fwd}})
		{
			$seenSpp{rev}{$fwd} = 1;
		}
	}


	open  OUTFILEFASTAFWD,  ">$outFileFastaFwd"  or print STDERR time, " $inFile :: COULD NOT OPEN $outFileFastaFwd : $!" && die;
	foreach my $fwd (sort keys %{$seenSpp{fwd}})
	{
		print OUTFILEFASTAFWD ">$fwd\n$fwd\n\n";
	}
	close OUTFILEFASTAFWD;

	open  OUTFILEFASTAREV,  ">$outFileFastaRev"  or print STDERR time, " $inFile :: COULD NOT OPEN $outFileFastaRev : $!" && die;
	foreach my $rev (sort keys %{$seenSpp{rev}})
	{
		print OUTFILEFASTAREV ">$rev\n$rev\n\n";
	}
	close OUTFILEFASTAREV;

}



sub parseValuePCR
{
	#GGCGGTGTGCCGGTCTCAATGTCTGTCGCC	552467.1{1671[(F,1237,30)]}
	my $seq = $_[0];
	my $val = $_[1];

	my @array;

	if (index($val, ";") == -1)
	{
		$array[0] = $val;
	}
	else
	{
		@array = split(";", $val)
	}

	#my %values;
	#map { $values{$_} = 1 } split(",", $storeValue);
	#$storeValue = join(",", keys %values);
	#0b60h7ac	4929.0{2[(F,224422,224446,224482,nBL6n0Lr,0=wn>HY.BBZYa)]}
	#0b60h7ac	4929.0{2[(F,224423,224446,224482,l2Bsj2Dga,0=wn>HY.BBZYa)]}

	if ( ! scalar(@array)    )
	{
	  print STDERR time, " $inFile :: NO PARTS :: \"$val\"\n";
	  return ""
	};


	foreach my $occ (@array)
	{
		#print STDERR time, " $inFile :: \tOCC $occ\n";
		if ($occ =~ /(\d+)\.(\d+)\{(.+?)\}/)
		{
			my $orgId = $1;
			my $var   = $2;
			my $info  = $3;
			my $whileInfoCount = 0;
			#print STDERR time, " $inFile :: \t\tORGID $orgId VAR $var INFO $info\n";

			while ($info =~ m/(\d+)\[(.+?)\]/g)
			{
				my   $chrom = $1;
				my   $pos   = $2;
				my   @poses;
				$whileInfoCount++;

				#print STDERR time, " $inFile :: \t\t\tCHROM $chrom POS $pos\n";

				if ( $pos  =~ /:/ )
				{
					@poses = split(":", $pos);
				}
				else
				{
					$poses[0] = $pos;
				}

				#print STDERR time, " $inFile :: \t\t\t\tPOSES ", join(";", @poses), "\n";
				if ( ! @poses )
				{
				  print STDERR time, " $inFile :: \t\t\t\tNO POSITTIONS FOUND $info :: $val\n";
				  return "";
				}

				foreach my $po (@poses)
				{
				    #(F,1237,30)
					if ($po =~ /\(([F|R]),(\d+),(\d+)\)/)
					{
						#print STDERR time, " $inFile :: \t\t\t\t\tPO $po\n";
						my $frame    = ($1 eq "F") ? 1 : 0;
						my $start    = $2;
						my $length   = $3;
						my $posCount = 0;

						#print STDERR time, " $inFile :: \t\t\t\t\t\tADDING ORG $orgId VAR $var CHROM $chrom START $start FRAME $frame SEQ $seq\n";
						$allValues{$orgId}[$var][$chrom]{$start}[$frame][0] = \$seq;
						$allValues{$orgId}[$var][$chrom]{$start}[$frame][1] = $start;
						$allValues{$orgId}[$var][$chrom]{$start}[$frame][2] = $frame;

					} # end if F|R,\d,\d,\d,\S,\S
					else
					{
						#warn "COULD NOT PARSE POSITIONS DETAILS: $po :: $val\n";
						print STDERR time, " $inFile :: COULD NOT PARSE POSITIONS DETAILS: \"$po\" :: \"$val\"\n";
						return "";
					}
				}
  				#print "Found '$&'.  Next attempt at character " . pos($string)+1 . "\n";
			} #end while \d[]

			if ( ! $whileInfoCount )
			{
			  #warn 'COULD NOT FIND \d[] ' . $info . " :: $val\n";
			  print STDERR time, "$inFile :: ", ' COULD NOT FIND \d[] "' . $info . "\" :: \"$val\"\n";
			  return "";
			}

		} # end if \d.\d{}
		else
		{
			#warn 'NO \d.\d{} FOUND: "' . $occ . '"' . " :: $val\n";
			print STDERR time, " $inFile :: " , ' NO \d.\d{} FOUND: "' . $occ . '"' . " ::\t\"$val\"\n";
			return "";
		}
	} # end foreach my $occ
}


sub loadXMLHeader
{
	my $xmlTax =
	"\t<!--		TAXONOMIC DATA		-->".
	"\n\t<tax>\n";

	foreach my $taxId (sort keys %tax)
	{
		$xmlTax .= "\t\t<org id=\"$taxId\">" . $tax{$taxId} . "</org>\n";
	}

	$xmlTax .= "\t</tax>\n\n";


	$XMLORGHEADER =
'<?xml version="1.0" encoding="ISO-8859-1"?>'.
"\n<orgs id=\"$inFile\">\n".
'';

	$XMLORGTAIL = '';





	$XMLPROBEHEADER =
'<?xml version="1.0" encoding="ISO-8859-1"?>
<?xml-stylesheet type="text/xml" href="#stylesheet"?>
<!DOCTYPE doc [
<!ATTLIST xsl:stylesheet id ID #REQUIRED>
]>
<data>
<!-- 	PROBES DATA 	-->
'.
"\t<probes id=\"$inFile\">\n";


	$XMLPROBETAIL = "\n$xmlTax\n\n" . '
<!--       STYLESHEET         -->
	<xsl:stylesheet id="stylesheet" version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
		<xsl:output method=\'html\'/>

<!--    VARIABLES DECLARATION        -->
		<xsl:param name="probesTxt"        select="\'probes\'"/>
		<xsl:param name="sumaryTitle"      select="\'SUMARY\'"/>
		<xsl:param name="space"            select="\', \'"/>
		<xsl:param name="sumaryOrgsTitle"  select="\'ORGANISMS\'"/>
		<xsl:param name="fwdTxt"           select="\'FWD: \'"/>
		<xsl:param name="revTxt"           select="\'REV: \'"/>
		<xsl:param name="orgTxt"           select="\'ORG: \'"/>
		<xsl:param name="varTxt"           select="\'VAR: \'"/>
		<xsl:param name="chromTxt"         select="\'CHROM: \'"/>
		<xsl:param name="fwdLabelStart"    select="\'FWD START\'"/>
		<xsl:param name="fwdLabelFrame"    select="\'FWD FRAME\'"/>
		<xsl:param name="fwdLabelSequence" select="\'FWD SEQUENCE\'"/>
		<xsl:param name="revLabelStart"    select="\'REV START\'"/>
		<xsl:param name="revLabelFrame"    select="\'REV FRAME\'"/>
		<xsl:param name="revLabelSequence" select="\'REV SEQUENCE\'"/>
		<xsl:param name="lengthLabel"      select="\'PRODUCT LENGTH\'"/>
		<xsl:param name="fwdKeysLabel"     select="\'FWD KEYS: \'"/>
		<xsl:param name="h"                select="round(count(data/summary/fwd) div 2) + 1"/>
		<xsl:param name="i"                select="$h - 1"/>
		<xsl:key name="forwards"  match="fwd" use="@id"/>
		<!--<xsl:for-each select="//fwd[generate-id() = generate-id(key(\'forwards\',@id)[1])]">
		<xsl:value-of select="$fwdKeysLabel"/><xsl:value-of select="@id"/> -->


<!--    HTML DATA       -->
		<xsl:template match="data">
			<html>
<!--    HEADER          -->
				<body style="font-family:Arial;font-size:12pt;background-color:#EEEEEE">
					<title><xsl:value-of select="probes/@id"/></title>
					<p align="center"><h1><b><xsl:value-of select="probes/@id"/></b></h1></p>
					<p align="right"><h4><i><xsl:value-of select="concat(count(summary/fwd), \' \', $probesTxt)"/></i></h4></p>

<!--    SUMARY          -->
					<font face="Courrier New">
						<table border="0" cellpadding="0" align="center" style="border-width:0px">
<!--	FIRST HALF OF TABLE     -->
							<th align="left" valign="top">
								<table border="0" cellpadding="0" align="left" style="border-width:0px">
									<tr bgcolor="#9acd32">
										<th align="left"><xsl:value-of select="$fwdLabelSequence"/> </th>
										<th align="left"><xsl:value-of select="$sumaryOrgsTitle"/>  </th>
									</tr>
									<xsl:for-each select="summary/fwd[position() &lt; $h]">
										<tr>
											<th align="left" valign="top">
												<a>
													<xsl:attribute name="href">#<xsl:value-of select="@id"/>
													</xsl:attribute>
													<xsl:value-of select="@id"/>
												</a>
											</th>
										<th align="left">
											<xsl:for-each select="org">
												<xsl:value-of select="."/><xsl:value-of select="$space"/>
											</xsl:for-each> <!-- end foreach org -->
										</th>
									  </tr>
									</xsl:for-each> <!-- end foreach fwd -->
								</table>
							</th>

<!-- 	SECOND HALF OF TABLE 		-->
							<th align="right" valign="top">
								<table border="0" cellpadding="0" align="right" style="border-width:0px">
									<tr bgcolor="#9acd32">
										<th align="left"><xsl:value-of select="$fwdLabelSequence"/> </th>
										<th align="left"><xsl:value-of select="$sumaryOrgsTitle"/>  </th>
									</tr>
									<xsl:for-each select="summary/fwd[position() &gt; $i]">
										<tr>
											<th align="left" valign="top">
												<a>
													<xsl:attribute name="href">#<xsl:value-of select="@id"/>
													</xsl:attribute>
													<xsl:value-of select="@id"/>
												</a>
											</th>
											<th align="left">
												<xsl:for-each select="org">
													<xsl:value-of select="."/><xsl:value-of select="$space"/>
												</xsl:for-each> <!-- end foreach org -->
											</th>
										</tr>
									</xsl:for-each> <!-- end foreach fwd -->
								</table>
							</th>
						</table>
					</font>



<!--	BODY 		-->
					<xsl:for-each select="probes/fwd">
						<div style="background-color:red;color:white;padding:8px;padding-left=0px">
							<span style="font-weight:bold">
								<a>
									<xsl:attribute name="name">
									  <xsl:value-of select="@id"/>
									</xsl:attribute>
								</a>
								<xsl:value-of select="$fwdTxt"/><xsl:value-of select="@id"/>
							</span>
						</div>
						<xsl:for-each select="rev">
							<div style="background-color:coral;color:white;padding:4px;padding-left:32px">
								<span style="font-weight:bold">
									<xsl:value-of select="$revTxt"/><xsl:value-of select="@id"/>
								</span>
							</div>
							<xsl:for-each select="org">
								<div style="background-color:lightSalmon;color:white;padding:2px;padding-left:48px">
									<span style="font-weight:bold">
										<xsl:value-of select="$orgTxt"/><xsl:value-of select="@id"/>
									</span>
								</div>
								<xsl:for-each select="var">
									<div style="background-color:peachpuff;color:black;padding:1px;padding-left:64px">
										<span style="font-weight:bold">
											<xsl:value-of select="$varTxt"/><xsl:value-of select="@id"/>
										</span>
									</div>
									<xsl:for-each select="chrom">
										<div style="background-color:white;color:black;padding:0px;padding-left:80px">
											<span style="font-weight:bold">
												<xsl:value-of select="$chromTxt"/><xsl:value-of select="@id"/>
											</span>
										</div>
										<table border="0" cellpadding="0" align="center" style="border-width:0px">
											<tr bgcolor="#9acd32">
												<th align="left"><xsl:value-of select="$fwdLabelStart"/>    </th>
												<th align="left"><xsl:value-of select="$fwdLabelFrame"/>    </th>
												<th align="left"><xsl:value-of select="$fwdLabelSequence"/> </th>
												<th align="left"><xsl:value-of select="$revLabelStart"/>    </th>
												<th align="left"><xsl:value-of select="$revLabelFrame"/>    </th>
												<th align="left"><xsl:value-of select="$revLabelSequence"/> </th>
												<th align="left"><xsl:value-of select="$lengthLabel"/>      </th>
											</tr>
											<xsl:for-each select="pos">
												<tr>
													<td><xsl:value-of select="fwdStart"/></td>
													<td><xsl:value-of select="fwdFrame"/></td>
													<td><xsl:value-of select="fwdSeq"/></td>
													<td><xsl:value-of select="revStart"/></td>
													<td><xsl:value-of select="revFrame"/></td>
													<td><xsl:value-of select="revSeq"/></td>
													<td><xsl:value-of select="prodLength"/></td>
												</tr>
												<!-- POS:    <xsl:value-of select="@id"/> -->
												<!-- FWDSEQ: <xsl:value-of select="fwdSeq"/> -->
												<!-- REVSEQ: <xsl:value-of select="revSeq"/> -->
											</xsl:for-each> <!-- POS -->
										</table>
									</xsl:for-each> <!-- CHROM -->
								</xsl:for-each> <!-- VAR -->
							</xsl:for-each> <!-- ORG -->
						</xsl:for-each> <!-- REV -->
					</xsl:for-each> <!-- PROBE/FWD -->
				</body>
			</html>
		</xsl:template>
	</xsl:stylesheet>
</data>
';



	#<tr bgcolor="#9acd32">
	#	<xsl:for-each select="child::*">
	#		<th align="left"><xsl:value-of select="name()"/>    </th>
	#	</xsl:for-each>
	#</tr>
	#<tr>
	#	<xsl:for-each select="child::*">
	#		<th align="left"><xsl:value-of select="."/>    </th>
	#	</xsl:for-each>
	#</tr>
}


sub getTaxonomy
{
	my $file     = $_[0];
    my $taxonomy = $_[1];
	open FILE, "<$file" or print STDERR time, " $inFile :: COULD NOT OPEN FASTA FILE $file: $!\n" && die;
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
					$taxonomy->{$fasta}[0] = $taxID;
					$taxonomy->{$fasta}[1] = $variant;
					$taxonomy->{$fasta}[2] = $fileType;
				}
			}
			elsif (/^#/)
			{

			}
			else
			{
				print STDERR time, " $inFile :: SKIPPED: ", $_, "\n"
			}
		}
	}
	print STDERR time, " $inFile :: $countValid FILES IN TAXONOMIC INDEX\n";
}


1;
