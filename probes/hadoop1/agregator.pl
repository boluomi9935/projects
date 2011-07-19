#!/usr/bin/perl -w

#v4 09.11.23.08.05
use strict;

my $storeValue  = '';
my $oldKey      = '';

while (<STDIN>)
{
  chomp;
  (my $key, my $value) = split "\t";
  
  if ( ! defined($oldKey) )
  {
	$oldKey      = $key;
	$storeValue  = $value;
  }
  else
  {
	next if ( ( ! defined $key ) || ( ! defined $value ) );
	
	if ($oldKey eq $key)
	{
		#$storeValue .= ",$value"; #v1
		#if ( ! ( $storeValue =~ /^\Q$value\E/ ) ) #v2
		#if (( ! ( $storeValue =~ /^\Q$value\E/ ) ) && ( ! ( $storeValue =~ /,\Q$value\E/ ) )) #v3
		#if ( ! ( $storeValue =~ /[^\d]\Q$value\E[^\d]/ ) ) #v4
		#{
		  #print "ADDING VALUE \"$value\" ONCE COUNT \"$storeValue\" DOESNT HAVE IT\n";
		  #$storeValue .= ",$value" ; #v2, v3
		#}
		
		#v5
		#my @values = split(",", $value);
		#foreach my $val (@values)
		#{
		#  if ( ! ( $storeValue =~ /[^\d]*$val[^\d]*/ ) )
		#  {
		#	$storeValue .= ",$val" ; #v2, v3
		#  }
		#}
		
		#v6
		$storeValue .= ",$value";
		my %values;
		map { $values{$_} = 1 } split(",", $storeValue);
		$storeValue = join(",", keys %values);
	}
	else
	{
		#v1
		#my @in = split(",", $storeValue);
		#if ( @in > 1 )
		#{
		#	my %places;
		#	map { $places{$_} = 1 } @in;
		#	$storeValue = join(",", keys %places);
		#}
		
		print "$oldKey\t$storeValue\n";
		$oldKey     = $key;
		$storeValue = $value;
	}
  }
}

#$storeValue = &checkCount($storeValue);
print "$oldKey\t$storeValue\n";

#sub checkCount
#{
#	my @in = split(",", $_[0]);
#	return $_[0] if ( @in == 1 );
#	
#	my %places;
#	map { $places{$_} = 1 } @in;
#	return join(",", keys %places);
#}
