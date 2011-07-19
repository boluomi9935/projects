#!/usr/bin/perl -w
use strict;

##############################################################################
#################################### SETUP ###################################
##############################################################################
my $file         = './taxonomy.verbose.tab';
my $outFileS     = './taxonomy.acc.tab';
my $outFileV     = './taxonomy.verbose.acc.tab';

##############################################################################
################################### PROGRAM ##################################
##############################################################################
my ($taxArray, $taxVerboseArray, $taxNamesArray, $taxLevelsNamesArray) = &getTaxArray($file);

open OUTS, ">$outFileS" or die "COULD NOT OPEN $outFileS : $!";
open OUTV, ">$outFileV" or die "COULD NOT OPEN $outFileV : $!";

#genus[21]	Aspergillus[5052]	Aspergillus clavatus[5057],Aspergillus flavus[5059],Aspergillus niger[5061],Aspergillus oryzae[5062],Aspergillus fumigatus[5085],Aspergillus terreus[33178]
#21	333750	333754,333757,333766,333767,337039,337041,337042,337044,337049,337050

for ( my $level = (@$taxVerboseArray - 1); $level >= 0; $level-- )
{
	next if ( ! defined ${$taxVerboseArray}[$level] );

	print "LEVEL $level [", $taxLevelsNamesArray->[$level], "]: (",scalar(@{$taxVerboseArray->[$level]}),")\n";

	for (my $name = 0; $name < @{$taxVerboseArray->[$level]}; $name++)
	{
		my $localKidsArray = $taxVerboseArray->[$level][$name];
		next if ( ! defined @{$localKidsArray} );
		
		print "  PARENT $name [",$taxNamesArray->[$name],"]\n";
		print "    KIDS: ";
		print join(", ", @$localKidsArray);
		print "\n";
		print OUTS "$level\t$name\t", join(",", @$localKidsArray), "\n";
		print OUTV $taxLevelsNamesArray->[$level], "\t", $taxNamesArray->[$name], "\t";

		my $kids;
		map {
			$kids .= "," if (defined $kids);
			$kids .= $taxNamesArray->[$_]
			} @$localKidsArray;

		print OUTV "$kids\n";
	}
}

close OUTS;
close OUTV;



##############################################################################
################################## FUNCTIONS #################################
##############################################################################
sub getTaxArray
{
	my $taxFile = $_[0];
	my @tax;
	my @names;
	my @levels;
	my @orgParentLevel;
	my $verbose = 0;

	open TAX, "<$taxFile" or die "COULD NOT OPEN TAXONOMY.TAB: $!";
	while (my $line = <TAX>)
	{
		#genus[21]	Aspergillus[5052]	Aspergillus clavatus[5057],Aspergillus flavus[5059],Aspergillus niger[5061],Aspergillus oryzae[5062],Aspergillus fumigatus[5085],Aspergillus terreus[33178]
		chomp $line;
		my ($level, $name, $kids) = split("\t", $line);

		my $levelName;
		if ($level =~ /\[(\d+)\]/)
		{
			#genus[21]
			$levels[$1] = $level;
			$levelName  = $level;
			$level      = $1;
		}

		my $nameName;
		if ($name =~ /\[(\d+)\]/)
		{
			#Aspergillus[5052]
			$names[$1] = $name;
			$nameName  = $name;
			$name      = $1;
		}

		printf "GLOBING LEVEL %02d [%s] NAME %06d [%s] KIDS %s\n", $level, $levelName, $name, $nameName, $kids if ( $verbose );

		#Aspergillus clavatus[5057],Aspergillus flavus[5059],Aspergillus niger[5061],Aspergillus oryzae[5062],Aspergillus fumigatus[5085],Aspergillus terreus[33178]
		my @kids = split(",", $kids);



		for (my $k = 0; $k < @kids; $k++)
		{
			my $kid = $kids[$k];
			if ($kid =~ /\[(\d+)\]/)
			{
				$names[$1] = $kid;
				$kid = $1;
				$orgParentLevel[$kid] = $level;
			}
			$kids[$k] = $kid;
		}

		$tax[$level][$name] = \@kids;
	}

	close TAX;

	#&savedump(\@tax,    "tax");
	#&savedump(\@names,  "names");
	#&savedump(\@levels, "levels");

	my @verboseTax;

	my $lastLevel  = @tax - 1 ;
	my $firstLevel = @tax - 1 ;
	for (my $level = (@tax - 1); $level >= 0; $level--)
	{
		next if ( ! defined @{$tax[$level]} );

		print "ANALYZING LEVEL $level [",$levels[$level],"] {$lastLevel}:\n" if ( $verbose );

		for (my $name = 0; $name <= @{$tax[$level]}; $name++)
		{
			next if ( ! defined $tax[$level][$name] );
			print "  ANALYZING $name [",$names[$name],"] :\n" if ( $verbose );

			if ($level == $firstLevel)
			{
				$verboseTax[$level][$name] = $tax[$level][$name];
				my $kids = $verboseTax[$level][$name];
				print "    KIDS eq ", join(", ", @$kids), "\n" if ( $verbose );
			}
			else
			{
				my $kids = $tax[$level][$name];
				#   $kids = &desintangleKids(\@tax, \@names, \@levels, \@orgParentLevel, $kids, $level, $name);

				foreach my $kid (@$kids)
				{
					print "    KID des $kid [", $names[$kid],"]\n" if ( $verbose );

					my $lLastLevel = $lastLevel;

					while ( ! defined @{$tax[$lLastLevel][$kid]} ) { $lLastLevel++; print "        KID $kid NOT DEFINED AT LAST LEVEL $lastLevel, REDUCING LEVEL TO ", $lLastLevel, "\n" if ( $verbose ); };
					print "        KIDS KIDS [$lLastLevel]: " if ( $verbose );

					foreach my $kKid (@{$tax[$lLastLevel][$kid]})
					{
						print "$kKid [",$names[$kKid],"]," if ( $verbose );
					}
					print "\n" if ( $verbose );

					push(@{$verboseTax[$level][$name]}, @{$verboseTax[$lLastLevel][$kid]}) if ($level != $firstLevel);
				}

				print "    NEW KIDS: " if ( $verbose );

				foreach my $nKid (@{$verboseTax[$level][$name]})
				{
					print "$nKid [",$names[$nKid],"]," if ( $verbose );
				}
				print "\n" if ( $verbose );
			}
		}
		print "\n\n" if ( $verbose );
		$lastLevel = $level if ($level != $lastLevel);
	}

	return \@tax, \@verboseTax, \@names, \@levels;
}


1;
