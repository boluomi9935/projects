#!/usr/bin/perl
while (<STDIN>)
{
  chomp;
  if (/(\d+\_\d+)\,(\w+)/)
  {
	print "$2\t$1\n";
  }
  else
  {
	die "NON CONFORMING: $_";
  }
  #print $line, "\t";
  #$hash{$line}++;
  #print "LongValueSum:", $line, "\t", $hash{$line}, "\n" if ($hash{$line} > 1);
}
