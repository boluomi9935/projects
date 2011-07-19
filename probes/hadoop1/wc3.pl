#!/usr/bin/perl -w

while (<STDIN>)
{
  chomp;
  my @pieces = split("\t");
  next if ( ! $pieces[0] );
  #$pieces[0] =~ s/\s+//;
  die "\"$_\"" if (@pieces != 2);
  print $pieces[0], "\t", $pieces[1], "\n";
}

