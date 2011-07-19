#!/usr/bin/perl -w

#v5 09.11.23.12.19
use strict;

my $storeValue  = undef;
my $oldKey      = undef;
my $amount      = $ARGV[0];

while (my $line = <STDIN>)
{
  chomp $line;
  next if ($line eq '');
  (my $key, my $value) = split "\t", $line;
  next if ( ( ! defined $key ) || ( ! defined $value ) );

  if ( ! defined($oldKey) )
  {
	$oldKey      = $key;
	$storeValue  = $value;
	#print "empty\n";
  }
  else
  {
	next if ( ( ! defined $key ) || ( ! defined $value ) );
	
	if ($oldKey eq $key)
	{
	  $storeValue .= ",$value";
	  my %values;
	  map { $values{$_} = 1 } split(",", $storeValue);
	  $storeValue = join(",", keys %values);
	  #print "STOREVALUE $key $value > $storeValue\n";
	}
	else
	{
	  my %values;
	  map { $values{$_} = 1 } split(",", $storeValue);
	  
	  if ((scalar(keys %values) == $amount) || ( $amount == 1 ))
	  {
		#print "\tAMMOUNT $amount STORE $storeValue\n";
		if ( $amount == 1 )
		{
		  $storeValue = substr($storeValue, 0, rindex($storeValue, '_'));
		}
		else
		{
		  my $radical = (keys %values)[0];
		  $storeValue = substr($radical, 0, rindex($radical, '_'));
		}
		print "$oldKey\t$storeValue\n";
	  }

	  $oldKey     = $key;
	  $storeValue = $value;
	}
  }
}


if (($storeValue =~ /,/) || ($amount == 1))
{
  my %values;
  map { $values{$_} = 1 } split(",", $storeValue);
  
  if ((scalar(keys %values) == $amount) || ( $amount == 1 ))
  {
	#print "\tAMMOUNT $amount STORE $storeValue\n";
	if ( $amount == 1 )
	{
	  $storeValue = substr($storeValue, 0, rindex($storeValue, '_'));
	}
	else
	{
	  my $radical = (keys %values)[0];
	  $storeValue = substr($radical, 0, rindex($radical, '_'));
	}
	print "$oldKey\t$storeValue\n" if (($oldKey ne '') && ($storeValue ne ''));
  }
}

