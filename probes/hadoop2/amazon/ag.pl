#!/usr/bin/perl -w
use strict;

my $count  = '';
my $oldKey = '';

while (<STDIN>)
{
  chomp;
  (my $key, my $value) = split "\t";
  
  if ( ! defined($oldKey) )
  {
	$oldKey = $key;
	$count  = $value;
  }
  else
  {
	if ($oldKey eq $key)
	{
		#$count .= ",$value"; #v1
		if ( ! ( $count =~ /\Q$value\E/ ) )
		{
		  #print "ADDING VALUE \"$value\" ONCE COUNT \"$count\" DOESNT HAVE IT\n";
		  $count .= ",$value" ; #v2
		}
	}
	else
	{
		#v1
		#my @in = split(",", $count);
		#if ( @in > 1 )
		#{
		#	my %places;
		#	map { $places{$_} = 1 } @in;
		#	$count = join(",", keys %places);
		#}
		
		print "$oldKey\t$count\n";
		$oldKey = $key;
		$count  = $value;
	}
  }
}

#$count = &checkCount($count);
print "$oldKey\t$count\n";

sub checkCount
{
	my @in = split(",", $_[0]);
	return $_[0] if ( @in == 1 );
	
	my %places;
	map { $places{$_} = 1 } @in;
	return join(",", keys %places);
}