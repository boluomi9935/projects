#!/usr/bin/perl -w
use strict;

#25	4959	58641
#25	5207	40410,178876
my $verbose = 0;
my $file    = "taxonomy.verbose.tab";
my $indir   = '/home/saulo/Desktop/rolf/rolf2/wc/output';
my $outdir  = '/home/saulo/Desktop/rolf/rolf2/wc/taxon';
#my $file    = "taxonomy.tab";

my @tax;
my @names;
$| = 1;

open TAX, "<$file" or die "COULD NOT OPEN TAXONOMY.TAB: $!";
while (my $line = <TAX>)
{
	chomp $line;
	my ($level, $name, $kids) = split("\t", $line);
	if ($name =~ /\[(\d+)\]/)
	{
		$names[$1] = $name;
		$name = $1;
	}
	#printf "GLOBING LEVEL %02d NAME %06d KIDS %s\n", $level, $name , $kids;
	
	my @kids = split(",", $kids);
	
	for (my $k = 0; $k < @kids; $k++)
	{
		my $kid = $kids[$k];
		if ($kid =~ /\[(\d+)\]/)
		{
			$names[$1] = $kid;
			$kid = $1;
		}
		$kids[$k] = $kid;
	}
	
	$tax[$name] = \@kids;
}

close TAX;

for (my $name = 0; $name <= @tax; $name++)
{
	next if ( ! defined $tax[$name] );
	print "ANALYZING $name [",$names[$name],"]\n";
	my $kids = $tax[$name];
	   $kids = &desintangleKids($kids, 0, $name);
	
	$tax[$name] = $kids;
	my $greps = "";
	foreach my $kid (@{$kids})
	{
		print "\tRESULT\t", $kid, "[",$names[$kid],"]\n";
		$greps .= " | grep $kid";
	}
	
	my $cmd1  = "cat $indir/shared*";
	my $cmd2  = " > $outdir/$name.wc";
	my $cmd   = "$cmd1 $greps $cmd2";
	my $lnCmd = "ln -s \"$outdir/$name.wc\" \"$outdir/" . $names[$name] . ".wc\"";
	my $wcCmd = "wc -l $outdir/$name.wc | gawk '{print \$1}'";
	print "\t\t$cmd\n";
	print "\t\t$lnCmd\n";
	print "\t\t$wcCmd\n";
	`$cmd`;
	`$lnCmd`;
	my $lines = `$wcCmd`;
	print "$lines LINES EXPORTED\n\n";
}


sub desintangleKids
{
	my $kids   = $_[0];
	my $level  = $_[1] || 0;
	my $father = $_[2] || ".";
	
	my @kids;
	print "\t", "__"x$level, "DESINTANGLING FATHER $father LEVEL $level\t", join("\t", @{$kids}), "\n" if ( $verbose );
	
	foreach my $kid (@{$kids})
	{
		print "\t", "    ", "____"x$level, "FOREACH FATHER $father LEVEL $level KID $kid\n" if ( $verbose );
		
		if ( defined $tax[$kid] )
		{
			print "\t", "      ", "______"x$level, "FATHER $father LEVEL $level KID $kid HAS KIDS\n" if ( $verbose );

			my $gkid = &desintangleKids($tax[$kid], $level++, $kid);

			foreach my $grandkid (@{$gkid})
			{
				print "\t", "        ", "________"x$level, "FATHER $father LEVEL $level KID $kid GRANKID > $grandkid\n" if ( $verbose );
				push(@kids, $grandkid);
			}
		}
		else
		{
			print "\t", "      ", "______"x$level, "FATHER $father LEVEL $level KID $kid HAS NO KIDS\n" if ( $verbose );
			push(@kids, $kid)
		}
	}
	
	print "\t", "__"x$level, "FATHER $father LEVEL $level DESINTANGLED\t", join("\t", @kids), "\n" if ( $verbose );
	print "\n\n" if  (( ! $level ) && ( $verbose ));
	
	return \@kids;
}