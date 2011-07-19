#!/usr/bin/perl
my %hash;

while (my $line = <STDIN>)
{
  chomp $line;
  #print $line, "\t";
  #$hash{$line}++;
  #print "LongValueSum:", $line, "\t", $hash{$line}, "\n" if ($hash{$line} > 1);
  print "LongValueSum:$line\t1\n";
}
