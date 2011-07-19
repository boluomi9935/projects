#!/usr/bin/perl -w
use strict;
use Cwd 'abs_path';

#list files on folder
# read each file
#  read the species
#   check if they make a natural group
#    YES = save with the code
#    NO  = save with wrong code
my $inFolder       = "out";
$inFolder = abs_path($inFolder);
my $inExtension    = ".had.sort.ag.*.had";
my $inExtensionZ   = ".had.sort.ag.*.had.gz";
my $outExtension   = ".tax.had";
my $taxonomyFile   = "taxonomy.verbose.acc.tab";
my $nonNaturalName = "nonNatural";
my %naturalGroups;
my %taxonFH;
my @inFiles;

&readTaxonomy($taxonomyFile, \%naturalGroups);
&mkTaxonomyFH(\%naturalGroups, \%taxonFH, $inFolder);
&listFiles($inFolder, $inExtension,  \@inFiles);
&listFiles($inFolder, $inExtensionZ, \@inFiles);
print "THERE ARE ",scalar(@inFiles)," FILES TO BE PROCESSED\n";
&parseFiles($inFolder, \@inFiles, \%taxonFH);
&closeTaxonomyFH(\%taxonFH);

sub parseFiles
{
	my $folder     = $_[0];
	my $inFile     = $_[1];
	my $taxFH      = $_[2];
	my $countFiles = 0;
	my $totalFiles = scalar(@$inFile);

	foreach my $file (@$inFile)
	{
		$countFiles++;
		my $fileName = $folder . "/" . $file;
		print "\tREADING FILE $fileName [$countFiles/$totalFiles]\n";
		
		if ($fileName =~ /gz$/)
		{
			open (INFILE, "/usr/bin/gunzip -c $fileName |") or die "COULD NOT OPEN FILENAME $fileName: $!";
		}
		else
		{
			open INFILE, "<$fileName" or die "COULD NOT OPEN FILENAME $fileName: $!";
		}

		while (my $line = <INFILE>)
		{
			#AAAAAAACCCGGCCGGGCGCGGTGGCTCAC	9606.0{1[(F,71284273,30)]23[(R,119515971,30)]5[(F,80075128,30)]};9598.0{3[(F,224304319,30)]7[(F,25740592,30)]24[(R,119958792,30)]}
			#chomp $line;
			die "NO LINE TO PARSE" if ($line eq "");
			#print "$line";

			my ($seq, $whom) = split("\t", $line);
			#print "\tSEQ $seq WHOM $whom";
			die "COULD NOT SPLIT" if ( ! ( ($seq) && ($whom)));

			my @orgIds;

			if (index($whom, ";") != -1)
			{
				my @whoms = split(";", $whom);
				foreach my $who (@whoms)
				{
					my $sppNum = substr($who, 0, index($who, "."));
					push(@orgIds, $sppNum);
				}
			}
			else
			{
				my $sppNum = substr($whom, 0, index($whom, "."));
				push(@orgIds, $sppNum);
			}

			@orgIds = sort { $a <=> $b } @orgIds;
			die "NO ORG ID" if ( ! @orgIds );

			my $literalOrgIds = join(",", @orgIds);
			die "NO LITERAL ORGANISM ID" if ( ! $literalOrgIds );
			#print "\t\tIDS FOUND: $literalOrgIds\n";

			if (exists ${$taxFH}{$literalOrgIds})
			{
				#print "LINE $literalOrgIds CREATED THE NATURAL GROUP ", $taxFH->{$literalOrgIds}[1], "\n";
				my $fh = $taxFH->{$literalOrgIds}[0];
				print $fh $line;
			}
			else
			{
				#print "LINE $literalOrgIds CREATED THE UNNATURAL GROUP ", $taxFH->{$nonNaturalName}[1], "\n";
				my $fh = $taxFH->{$nonNaturalName}[0];
				print $fh $line;
			}
		}
		close INFILE;
	}

}


sub listFiles
{
	my $folder = $_[0];
	my $ext    = $_[1];
	my $array  = $_[2];

	opendir (DIR, "$folder") or die "COULD NOT OPEN FOLDER $folder : $!";
	my @dArray = sort grep /$ext$/, readdir(DIR);
	closedir DIR;

	print "TOTAL INPUT FILES IN FOLDER $folder WITH EXTENSION $ext: ", scalar(@dArray), "\n";
	push(@$array, @dArray);
}


sub closeTaxonomyFH
{
	my $fhHash = $_[0];
	foreach my $lFh (keys %$fhHash)
	{
		close $lFh;
	}
}

sub mkTaxonomyFH
{
	my $groups = $_[0];
	my $fh     = $_[1];
	my $folder = $_[2];

	foreach my $natural (sort keys %$groups)
	{
		my $group    = $groups->{$natural}[1];
		my $name     = $groups->{$natural}[2];
		my $fileName = "$folder/$group$outExtension";
		my $linkName = "$folder/$name$outExtension";

		print "CREATING TAXON FH FOR NATURAL GROUP $group ON FILE $fileName CONPRISING OF $natural LINKING TO $linkName\n";
		open (my $lFh, ">$fileName") or die "COULD NOT CREATE FILENAME $fileName : $!";
		$fh->{$natural}[0] = $lFh;
		$fh->{$natural}[1] = $group;
		$fh->{$natural}[2] = $name;

		`ln -s $fileName $linkName 2>/dev/null`;
	}

	my $group    = $nonNaturalName;
	my $fileName = "$folder/$group$outExtension";
	print "CREATING TAXON FH FOR NATURAL GROUP $group ON FILE $fileName CONPRISING OF $nonNaturalName\n";
	open (my $lFh, ">$fileName") or die "COULD NOT CREATE FILENAME $fileName : $!";
	$fh->{$group}[0] = $lFh;
	$fh->{$group}[1] = $group;
	$fh->{$group}[2] = $group;
}


sub readTaxonomy
{
	my $file = $_[0];
	my $hash = $_[1];

	open TAX, "<$file" or die "COULD NOT OPEN $file: $!";
	while (my $line = <TAX>)
	{
		#genus[21]	Aspergillus[5052]	Aspergillus clavatus[5057],Aspergillus flavus[5059],Aspergillus niger[5061],Aspergillus oryzae[5062],Aspergillus fumigatus[5085],Aspergillus terreus[33178]
		chomp $line;
		my ($level, $name, $kids) = split("\t", $line);

		if ($level =~ /\[(\d+)\]/)
		{
			#genus[21]
			$level      = $1;
		}

		my $nameName;
		if ($name =~ /\[(\d+)\]/)
		{
			#Aspergillus[5052]
			$nameName  = $name;
			$name      = $1;
		}

		#Aspergillus clavatus[5057],Aspergillus flavus[5059],Aspergillus niger[5061],Aspergillus oryzae[5062],Aspergillus fumigatus[5085],Aspergillus terreus[33178]
		my @kids;
		@{$kids[0]} = split(",", $kids);

		for (my $k = 0; $k < @{$kids[0]}; $k++)
		{
			my $kid = $kids[0][$k];
			my $kidName;
			if ($kid =~ /\[(\d+)\]/)
			{
				$kidName = $kid;
				$kid     = $1;
			}
			$kids[1][$k] = $kid;
		}

		my $kidsLiteral = join(",", sort { $a <=> $b } @{$kids[1]});
		$hash->{$kidsLiteral}[0] = $level;
		$hash->{$kidsLiteral}[1] = $name;
		$hash->{$kidsLiteral}[2] = $nameName;
	}
	close TAX;
	print "NATURAL GROUPS OBTAINED: ", scalar(keys %$hash), "\n";
}




1;
