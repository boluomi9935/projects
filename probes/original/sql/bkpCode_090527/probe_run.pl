#!/usr/bin/perl -w
use strict;

my $indir     = $ARGV[0] || "input";
my $optRate   = 1000;
my $optScript = "/home/saulo/Desktop/rolf/sql/probe_6_optimize.sql";
my %taxonomy;

if (1)
{
	`/home/saulo/Desktop/rolf/sql/startSql.sh`;
}

opendir (DIR, "$indir") or die $!;
my @infiles = grep /\.fasta$/, readdir(DIR);
closedir DIR;
$| = 1;

&getTaxonomy("$indir/taxonomy.idx");


if ( ! @infiles ) { die "NO FASTA FILES FOUND IN $indir DIRECTORY"};
# my $file     = "candida_albicans_wo1_1_contigs.fasta";
# my $file     = "../rolf3_cawo1_2_short.fasta";
my $cFile = 0;



my $fileOut = "#!/bin/sh\n";



$fileOut .= "echo \"" . ":"x40 . "\"\n";
$fileOut .= "echo \"RUNNING OVER " . scalar(@infiles) . " FILES:\"\n";
foreach my $file (sort @infiles)
{
	if (exists $taxonomy{$file})
	{
		$fileOut .= "echo \"\t$file\"\n";
	}
	else
	{
		die "FASTA FILE $file NOT IN TAXONOMY FILE\n: $!";
	}
}
$fileOut .=  "echo \"" . ":"x40 . "\n\n\"\n\n";




my $opt = "echo \"" . "."x20 . "\"\n";
$opt   .= "echo \"OPTIMIZING\"\n";
$opt   .= "echo \"" . "."x20 . "\"\n";
$opt   .= "time sudo mysql -u probe < $optScript\n\n";

$fileOut .=  $opt;



foreach my $file (sort @infiles)
{
	$cFile++;
	$fileOut .=  "echo \"" . "#"x20 . "\"\n";
	$fileOut .=  "echo \"RUNNING FILE $cFile OUT OF " . scalar(@infiles) . "\t$file\"\n";
	$fileOut .=  "echo \"" . "#"x20 . "\"\n";

	if ( !($cFile % $optRate)) { print FILE $opt; };
	my $taxonId      = $taxonomy{$file}[0];
	my $variant      = $taxonomy{$file}[1];
	my $sequenceType = $taxonomy{$file}[2];
	my $command = "time ./probe_extractor.pl $indir $file $taxonId $variant $sequenceType ";
	$fileOut .=  "$command\n";

	$fileOut .=  "rm /mnt/ssd/probes/dumps/*.dump\n";
	$fileOut .=  "/mnt/ssd/probes/insert.sh &\n";
	$fileOut .=  "sleep 2\n";
	$fileOut .=  "echo \"" . "*"x20 . "\"\n";
	$fileOut .=  "echo \"FINISH RUNNING FILE $cFile OUT OF " . scalar(@infiles) . "\t$file\"\n";
	$fileOut .=  "echo \"" . "*"x20 . "\n\n\n\"\n\n\n";

}


$fileOut .=  $opt;

open  FILE, ">run.sh" or die "COULD NOT CREATE RUN.SH SCRIPT";
print FILE $fileOut;
close FILE;
`chmod +x run.sh`;

print @infiles . " FILES TO BE ANALIZED\n";
print "!"x40 . "\nPLEASE EXECUTE\ntime ./run.sh\n" . "!"x40 . "\n";

# print `./probe_uniq.pl $outdir`;



sub getTaxonomy
{
	my $file = $_[0];
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
	print "$countValid FILES IN TAXONOMIC INDEX\n";
}


1;
