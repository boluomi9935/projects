#FASTAFILE=Arabidopsis_thaliana_CHROMOSSOMES
#HADFILE="37020.tax.had"

FASTAFILE=Cryptococcus_gattii_R265_CHROMOSSOMES
HADFILE="5524670.tax.had"

echo EXTRACTING THE CHROMOSSOME SIZES
cat ${FASTAFILE}.fasta | perl -ne 'BEGIN{ my %chroms; my $last; } END{
    my $count = 1;
	foreach my $chrom (sort keys %chroms)
	{
		print $chrom, "\t", $count++, "\t", $chroms{$chrom}, "\n";
	}
}
if (/^>(\S+)/)
{
	$last = $1;
} else {
#print $last, "\t", length($_), "\n";
$chroms{$last} += length($_);
}
' > ${FASTAFILE}.count


#3702.0{7[(R,80584,30)]2[(R,3471151,30)]}
echo EXTRACTING PROBES POSITIONS
cat ${HADFILE} | gawk '{print $2}' | perl -ne '
#print;
while (/(\d+)\[(\S+?)\]/xg)
{
    my $chromNum = $1;
    my $chromNfo = $2;
    #print "\tCHROM $1 NFO $2\n";
    while ($chromNfo =~ /\([R|F],(\d+),\d+\)/g)
    {
        my $pos = $1;
        #print "\t\tPOS $pos\n";
        print "$chromNum\t$pos\n";
    }
}

' > ${HADFILE}.pos



echo EXPORTING TAB FILE
cat ${HADFILE}.pos | perl -ne '
my @max;
BEGIN
{
	use strict;
	use warnings;
	my @chroms;

	open FI, "'${FASTAFILE}'.count";
	while (my $ln = <FI>)
	{
		chomp $ln;
		my @line = split("\t", $ln);
		$max[$line[1]] = $line[2];
		#print "CHROM NAME \"", $line[0], "\"\tCHROM NUM \"", $line[1], "\"\tSIZE \"", $max[$line[1]], "\"\n";
	}
	close FI;
}

chomp;
my @line = split("\t", $_);
#print "CHROM NUM ", $line[0], " POS ", $line[1], "\n";
$chroms[$line[0]]{$line[1]} = 1;

END
{
	print "MAX    KEYS ", scalar (keys %max),    "\n";
	print "CHROMS KEYS ", scalar (keys %chroms), "\n";
	for (my $chromNum = 1; $chromNum < @chroms; $chromNum++)
	{
		#die if ( ! exists $max{$chrom} );
		my $mx = $max[$chromNum];
		print "CHROM NUM \"$chromNum\"\tMAX\t$mx\n";
        unlink("snpspos.$chrom.tab");
		open EX, ">'${HADFILE}'.$chromNum.tab";
		for (my $p = 0; $p < $mx; $p++)
		{
			if ( exists ${$chroms[$chromNum]}{$p} )
			     { print EX "$p\t1\n"; }
			else { print EX "$p\t0\n"; }
		}
		close EX;
	}
}
'





echo EXPORTING IMAGES
for file in ${HADFILE}.*.tab
do
rm $file.png 2>/dev/null
echo EXPORTING FILE $file
PLOT='set title "PROBES distribution - '$file'"
set xlabel "position"
#set xrange [0:$xSize]
set yrange [0:1]
set bars small

set style line 3 lt rgb '"'"'red'"'"'   lw 1

set grid
set palette model RGB
set pointsize 0.0005

set terminal png size 1024,768 large font "/usr/share/fonts/default/ghostscript/putr.pfa,12"
set output '"'"''$file'.png'"'"'

plot '"'"''$file''"'"' with impulses notitle ls 3
 #with steps

exit
'


echo "$PLOT" | gnuplot
done



echo DONE
