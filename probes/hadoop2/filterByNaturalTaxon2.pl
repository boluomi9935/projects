#!/usr/bin/perl -w
use strict;
my %fhs;

#IN ORDER TO RUN PLEASE ADD
#*               -        nofile	       	 2048
#TO /etc/security/limits.conf
#OR RUN AS ROOT ulimit -n 2048
#CHECK BY RUNNING ulimit -a
$|=1;


my $outExtension = ".tax.had";
my $countFiles   = 0;
my $outDir       = "out/";

while (my $line = <STDIN>)
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
			my $sppNum = substr($who, 0, index($who, "{"));
			push(@orgIds, $sppNum);
		}
	}
	else
	{
		my $sppNum = substr($whom, 0, index($whom, "{"));
		push(@orgIds, $sppNum);
	}

	@orgIds = sort { $a <=> $b } @orgIds;
	die "NO ORG ID" if ( ! @orgIds );

	my $literalOrgIds = join(",", @orgIds);
	$literalOrgIds =~ s/\.//g;
	die "NO LITERAL ORGANISM ID" if ( ! $literalOrgIds );
	#print "\t\tIDS FOUND: $literalOrgIds\n";

	if ( ! exists $fhs{$literalOrgIds})
	{
		&mkTaxonomyFH($literalOrgIds);
	}

	my $fh = $fhs{$literalOrgIds};
	print $fh $line;
	#print "$literalOrgIds > $line\n"
}

#&closeTaxonomyFH();


sub mkTaxonomyFH
{
	my $group    = $_[0];
	my $fileName = $outDir . $group . $outExtension;

	printf "CREATING TAXON FH [%04d] :: GROUP %s ON FILE %s\n",++$countFiles,$group,$fileName;
	open (my $lFh, ">$fileName") or die "COULD NOT CREATE FILENAME $fileName : $!";
	$fhs{$group} = $lFh;
}


sub closeTaxonomyFH
{
	foreach my $lFh (keys %fhs)
	{
		close $lFh;
	}
}

1;
