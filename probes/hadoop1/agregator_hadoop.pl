#!/usr/bin/perl -w

#v06/h 09.12.28.00.00
use strict;

my $storeValue  = '';
my $oldKey      = '';
my $parser      = \&parseValuePCR;
#my $parser      = \&parseValueMLPANew;
#my $parser      = \&parseValueMLPAOrig;

while (<STDIN>)
{
  chomp;
  (my $key, my $value) = split "\t";
  next if ( ( ! defined $key ) || ( ! defined $value ) );

  if ( $oldKey eq '' )
  {
	$oldKey      = $key;
	$storeValue  = $value;
  }
  else
  {
	next if ( ( ! defined $key ) || ( ! defined $value ) );

	if ($oldKey eq $key)
	{
	  $storeValue .= ";$value";
	}
	else
	{
	  #if ( ! ( $storeValue =~ /\;/ ) )
	 # {
	#	print "$oldKey\t$storeValue\n";
	#	$oldKey     = $key;
	#	$storeValue = $value;
	  #}
	  #else
	  #{
		#print "M1 $oldKey\t$storeValue\n";
		my $condensed = $parser->($storeValue);
		if ( $condensed ne "" )
		{
		  print $oldKey, "\t", $condensed, "\n";
		  $oldKey     = $key;
		  $storeValue = $value;
		}
		else
		{
		  #warn "NO CONDENSATION: $key\n$value\n";
		  print STDERR "NO CONDENSATION:\nOLD:\t\"$oldKey\"\t\"$storeValue\"\nNEW:\t\"$key\"\t\"$value\"\n\n\n";
                  $oldKey     = $key;
                  $storeValue = $value;
		}
	  #}
	}
  }
}



#if ( ! ( $storeValue =~ /\;/ ) )
#{
#  print "$oldKey\t$storeValue\n";
#}
#else
#{
  #print "M1 $oldKey\t$storeValue\n";
  my $condensed = $parser->($storeValue);

  if ( $condensed ne "" )
  {
	print $oldKey,"\t",$condensed,"\n";
  }
  else
  {
    #warn "ERROR LAST \"$oldKey\t$storeValue\"\n";
    print STDERR "\tERROR LAST \"$oldKey\t$storeValue\"\n";
  }
#}









sub parseValuePCR
{
	#GGCGGTGTGCCGGTCTCAATGTCTGTCGCC	552467.1{1671[(F,1237,30)]}
	my $val = $_[0];
	my @array;
	if (index($val, ";") != -1)
	{
	  @array = split(";", $val)
	}
	else
	{
	  $array[0] = $val;
	}

	#my %values;
	#map { $values{$_} = 1 } split(",", $storeValue);
	#$storeValue = join(",", keys %values);
	#0b60h7ac	4929.0{2[(F,224422,224446,224482,nBL6n0Lr,0=wn>HY.BBZYa)]}
	#0b60h7ac	4929.0{2[(F,224423,224446,224482,l2Bsj2Dga,0=wn>HY.BBZYa)]}

	if ( ! scalar(@array)    )
	{
	  #warn "NO PARTS :: $val\n";
	  print STDERR "\tNO PARTS :: \"$val\"\n";
	  return ""
	};

	if ( scalar(@array) == 1 ) { return $val };
	my %hash;

	foreach my $occ (@array)
	{
		if ($occ =~ /(\d+)\.(\d+)\{(.+?)\}/)
		{
			my $orgId = $1;
			my $var   = $2;
			my $info  = $3;
			my $whileInfoCount = 0;
			#print "\tORGID $orgId VAR $var INFO $info\n";

			while ($info =~ m/(\d+)\[(.+?)\]/g)
			{
				my   $chrom = $1;
				my   $pos   = $2;
				my   @poses;
				$whileInfoCount++;

				#print "\t\tCHROM $chrom POS $pos\n";

				if ( $pos  =~ /:/ )
				{
					@poses = split(":", $pos);
				}
				else
				{
					$poses[0] = $pos;
				}

				#print "\t\tPOSES ", join(";", @poses), "\n";
				if ( ! @poses )
				{
				  #warn "NO POSITTIONS FOUND $info :: $val\n";
				  print STDERR "\tNO POSITTIONS FOUND $info :: $val\n";
				  return "";
				}

				foreach my $po (@poses)
				{
				    #(F,1237,30)
					if ($po =~ /\(([F|R]),(\d+),(\d+)\)/)
					{
						#print "\t\t\t\tPO $po\n";
						my $frame    = $1;
						my $posCount = 0;
						if ( defined @{$hash{$orgId}[$var]{$chrom}} )
						{
							$posCount = @{$hash{$orgId}[$var]{$chrom}};
						}
						$hash{$orgId}[$var]{$chrom}[$posCount] = $po;

					} # end if F|R,\d,\d,\d,\S,\S
					else
					{
						#warn "COULD NOT PARSE POSITIONS DETAILS: $po :: $val\n";
						print STDERR "\tCOULD NOT PARSE POSITIONS DETAILS: \"$po\" :: \"$val\"\n";
						return "";
					}
				}
  				#print "Found '$&'.  Next attempt at character " . pos($string)+1 . "\n";
			} #end while \d[]

			if ( ! $whileInfoCount )
			{
			  #warn 'COULD NOT FIND \d[] ' . $info . " :: $val\n";
			  print STDERR "\t" . 'COULD NOT FIND \d[] "' . $info . "\" :: \"$val\"\n";
			  return "";
			}

		} # end if \d.\d{}
		else
		{
			#warn 'NO \d.\d{} FOUND: "' . $occ . '"' . " :: $val\n";
			print STDERR "\t" . 'NO \d.\d{} FOUND: "' . $occ . '"' . " ::\t\"$val\"\n";
			return "";
		}
	} # end foreach my $occ



	my $outStr;
	#0b60h7ac	4929.0{2[(F,224423,224446,224482,l2Bsj2Dga,0=wn>HY.BBZYa)]}
	if ( ! scalar(keys %hash) )
	{
	  #warn "NO ORGIDS :: $val\n";
	  print STDERR "\tNO ORGIDS :: \"$val\"\n";
	  return "";
	}

	foreach my $orgId (keys %hash)
	{
		#print "ORGID $orgId\n";
		if ( ! scalar(@{$hash{$orgId}}) )
		{
		  #warn "NO VARS :: $val\n";
		  print STDERR "\tNO VARS :: \"$val\"\n";
		  return "";
		}

		for (my $var = 0; $var < @{$hash{$orgId}}; $var++)
		{
			#$hash{$orgId}[$var]{$chrom}{$pos}[5] = $m13Seq;
			next if ( ! defined ${$hash{$orgId}}[$var] );
			#print "\tVAR $var\n";
			#print "\tCHROMS",,"\n";
			$outStr .= ";" if ( defined $outStr );
			$outStr .= "$orgId.$var\{";

			if ( ! keys %{$hash{$orgId}[$var]} )
			{
			  #warn "NO CHROM :: $val\n";
			  print STDERR "\tNO CHROM :: \"$val\"\n";
			  return "";
			}

			foreach my $chrom ( keys %{$hash{$orgId}[$var]} )
			{
				#print "\t\tCHROM $chrom ", @{$hash{$orgId}[$var]{$chrom}} ,"\n";
				$outStr .= "$chrom\[";
				my $po1;

				if ( ! scalar(@{$hash{$orgId}[$var]{$chrom}}) )
				{
				  #warn "NO POS :: $val\n";
				  print STDERR "\tNO POS :: \"$val\"\n";
				  return "";
				}

				for (my $pos = 0; $pos < @{$hash{$orgId}[$var]{$chrom}}; $pos++ )
				{
		        		my $po = $hash{$orgId}[$var]{$chrom}[$pos];
					$po1  .= ":" if (defined $po1);
					$po1  .= $po;
				}
				$outStr .= "$po1]";
			}
			$outStr .= "}";
		} # end foreach my var
	} # end foreach my orgid

	if ( ! $outStr )
	{
	  #warn "NO OUTPUT :: \"$val\"\n";
	  print STDERR "\tNO OUTPUT :: \"$val\"\n";
	  return "";
	};

	return $outStr;
}






sub parseValueMLPANew
{
	my $val = $_[0];
	my @array;
	if ($val =~ /\;/)
	{
	  @array = split(";", $val)
	}
	else
	{
	  $array[0] = $val;
	}

	#my %values;
	#map { $values{$_} = 1 } split(",", $storeValue);
	#$storeValue = join(",", keys %values);
	#0b60h7ac	4929.0{2[(F,224422,224446,224482,nBL6n0Lr,0=wn>HY.BBZYa)]}
	#0b60h7ac	4929.0{2[(F,224423,224446,224482,l2Bsj2Dga,0=wn>HY.BBZYa)]}

	if ( ! scalar(@array)    )
	{
	  #warn "NO PARTS :: $val\n";
	  print STDERR "\tNO PARTS :: \"$val\"\n";
	  return ""
	};

	if ( scalar(@array) == 1 ) { return $val };
	my %hash;

	foreach my $occ (@array)
	{
		if ($occ =~ /(\d+)\.(\d+)\{(.+?)\}/)
		{
			my $orgId = $1;
			my $var   = $2;
			my $info  = $3;
			my $whileInfoCount = 0;
			#print "\tORGID $orgId VAR $var INFO $info\n";

			while ($info =~ m/(\d+)\[(.+?)\]/g)
			{
				my   $chrom = $1;
				my   $pos   = $2;
				my   @poses;
				$whileInfoCount++;

				#print "\t\tCHROM $chrom POS $pos\n";

				if ( $pos  =~ /:/ )
				{
					@poses = split(":", $pos);
				}
				else
				{
					$poses[0] = $pos;
				}

				#print "\t\tPOSES ", join(";", @poses), "\n";
				if ( ! @poses )
				{
				  #warn "NO POSITTIONS FOUND $info :: $val\n";
				  print STDERR "\tNO POSITTIONS FOUND $info :: $val\n";
				  return "";
				}

				foreach my $po (@poses)
				{
				    #(F,nofziS>vvvvx,12611001,QpfmYZ|!I*n_c)
					if ($po =~ /\(([F|R]),(\d+),(\d+),(\d+),(\S+?),(\S+?)\)/)
					{
						#print "\t\t\t\tPO $po\n";
						my $frame    = $1;
						my $posCount = 0;
						if ( defined @{$hash{$orgId}[$var]{$chrom}} )
						{
							$posCount = @{$hash{$orgId}[$var]{$chrom}};
						}
						$hash{$orgId}[$var]{$chrom}[$posCount] = $po;

					} # end if F|R,\d,\d,\d,\S,\S
					else
					{
						#warn "COULD NOT PARSE POSITIONS DETAILS: $po :: $val\n";
						print STDERR "\tCOULD NOT PARSE POSITIONS DETAILS: \"$po\" :: \"$val\"\n";
						return "";
					}
				}
  				#print "Found '$&'.  Next attempt at character " . pos($string)+1 . "\n";
			} #end while \d[]

			if ( ! $whileInfoCount )
			{
			  #warn 'COULD NOT FIND \d[] ' . $info . " :: $val\n";
			  print STDERR "\t" . 'COULD NOT FIND \d[] "' . $info . "\" :: \"$val\"\n";
			  return "";
			}

		} # end if \d.\d{}
		else
		{
			#warn 'NO \d.\d{} FOUND: "' . $occ . '"' . " :: $val\n";
			print STDERR "\t" . 'NO \d.\d{} FOUND: "' . $occ . '"' . " ::\t\"$val\"\n";
			return "";
		}
	} # end foreach my $occ



	my $outStr;
	#0b60h7ac	4929.0{2[(F,224423,224446,224482,l2Bsj2Dga,0=wn>HY.BBZYa)]}
	if ( ! scalar(keys %hash) )
	{
	  #warn "NO ORGIDS :: $val\n";
	  print STDERR "\tNO ORGIDS :: \"$val\"\n";
	  return "";
	}

	foreach my $orgId (keys %hash)
	{
		#print "ORGID $orgId\n";
		if ( ! scalar(@{$hash{$orgId}}) )
		{
		  #warn "NO VARS :: $val\n";
		  print STDERR "\tNO VARS :: \"$val\"\n";
		  return "";
		}

		for (my $var = 0; $var < @{$hash{$orgId}}; $var++)
		{
			#$hash{$orgId}[$var]{$chrom}{$pos}[5] = $m13Seq;
			next if ( ! defined ${$hash{$orgId}}[$var] );
			#print "\tVAR $var\n";
			#print "\tCHROMS",,"\n";
			$outStr .= ";" if ( defined $outStr );
			$outStr .= "$orgId.$var\{";

			if ( ! keys %{$hash{$orgId}[$var]} )
			{
			  #warn "NO CHROM :: $val\n";
			  print STDERR "\tNO CHROM :: \"$val\"\n";
			  return "";
			}

			foreach my $chrom ( keys %{$hash{$orgId}[$var]} )
			{
				#print "\t\tCHROM $chrom ", @{$hash{$orgId}[$var]{$chrom}} ,"\n";
				$outStr .= "$chrom\[";
				my $po1;

				if ( ! scalar(@{$hash{$orgId}[$var]{$chrom}}) )
				{
				  #warn "NO POS :: $val\n";
				  print STDERR "\tNO POS :: \"$val\"\n";
				  return "";
				}

				for (my $pos = 0; $pos < @{$hash{$orgId}[$var]{$chrom}}; $pos++ )
				{
		        		my $po = $hash{$orgId}[$var]{$chrom}[$pos];
					$po1  .= ":" if (defined $po1);
					$po1  .= $po;
				}
				$outStr .= "$po1]";
			}
			$outStr .= "}";
		} # end foreach my var
	} # end foreach my orgid

	if ( ! $outStr )
	{
	  #warn "NO OUTPUT :: \"$val\"\n";
	  print STDERR "\tNO OUTPUT :: \"$val\"\n";
	  return "";
	};

	return $outStr;
}





sub parseValueMLPAOrig
{
	my $val = $_[0];
	my @array;
	if ($val =~ /\;/)
	{
	  @array = split(";", $val)
	}
	else
	{
	  $array[0] = $val;
	}

	#my %values;
	#map { $values{$_} = 1 } split(",", $storeValue);
	#$storeValue = join(",", keys %values);
	#0b60h7ac	4929.0{2[(F,224422,224446,224482,nBL6n0Lr,0=wn>HY.BBZYa)]}
	#0b60h7ac	4929.0{2[(F,224423,224446,224482,l2Bsj2Dga,0=wn>HY.BBZYa)]}

	if ( ! scalar(@array)    )
	{
	  #warn "NO PARTS :: $val\n";
	  print STDERR "\tNO PARTS :: \"$val\"\n";
	  return ""
	};

	if ( scalar(@array) == 1 ) { return $val };
	my %hash;

	foreach my $occ (@array)
	{
		if ($occ =~ /(\d+)\.(\d+)\{(.+?)\}/)
		{
			my $orgId = $1;
			my $var   = $2;
			my $info  = $3;
			my $whileInfoCount = 0;
			#print "\tORGID $orgId VAR $var INFO $info\n";

			while ($info =~ m/(\d+)\[(.+?)\]/g)
			{
				my   $chrom = $1;
				my   $pos   = $2;
				my   @poses;
				$whileInfoCount++;

				#print "\t\tCHROM $chrom POS $pos\n";

				if ( $pos  =~ /:/ )
				{
					@poses = split(":", $pos);
				}
				else
				{
					$poses[0] = $pos;
				}

				#print "\t\tPOSES ", join(";", @poses), "\n";
				if ( ! @poses )
				{
				  #warn "NO POSITTIONS FOUND $info :: $val\n";
				  print STDERR "\tNO POSITTIONS FOUND $info :: $val\n";
				  return "";
				}

				foreach my $po (@poses)
				{
				    #(F,nofziS>vvvvx,12611001,QpfmYZ|!I*n_c)
					if ($po =~ /\(([F|R]),(\d+),(\d+),(\d+),(\S+?),(\S+?)\)/)
					{
						#print "\t\t\t\tPO $po\n";
						my $frame    = $1;
						my $posCount = 0;
						if ( defined @{$hash{$orgId}[$var]{$chrom}} )
						{
							$posCount = @{$hash{$orgId}[$var]{$chrom}};
						}
						$hash{$orgId}[$var]{$chrom}[$posCount] = $po;

					} # end if F|R,\d,\d,\d,\S,\S
					else
					{
						#warn "COULD NOT PARSE POSITIONS DETAILS: $po :: $val\n";
						print STDERR "\tCOULD NOT PARSE POSITIONS DETAILS: \"$po\" :: \"$val\"\n";
						return "";
					}
				}
  				#print "Found '$&'.  Next attempt at character " . pos($string)+1 . "\n";
			} #end while \d[]

			if ( ! $whileInfoCount )
			{
			  #warn 'COULD NOT FIND \d[] ' . $info . " :: $val\n";
			  print STDERR "\t" . 'COULD NOT FIND \d[] "' . $info . "\" :: \"$val\"\n";
			  return "";
			}

		} # end if \d.\d{}
		else
		{
			#warn 'NO \d.\d{} FOUND: "' . $occ . '"' . " :: $val\n";
			print STDERR "\t" . 'NO \d.\d{} FOUND: "' . $occ . '"' . " ::\t\"$val\"\n";
			return "";
		}
	} # end foreach my $occ



	my $outStr;
	#0b60h7ac	4929.0{2[(F,224423,224446,224482,l2Bsj2Dga,0=wn>HY.BBZYa)]}
	if ( ! scalar(keys %hash) )
	{
	  #warn "NO ORGIDS :: $val\n";
	  print STDERR "\tNO ORGIDS :: \"$val\"\n";
	  return "";
	}

	foreach my $orgId (keys %hash)
	{
		#print "ORGID $orgId\n";
		if ( ! scalar(@{$hash{$orgId}}) )
		{
		  #warn "NO VARS :: $val\n";
		  print STDERR "\tNO VARS :: \"$val\"\n";
		  return "";
		}

		for (my $var = 0; $var < @{$hash{$orgId}}; $var++)
		{
			#$hash{$orgId}[$var]{$chrom}{$pos}[5] = $m13Seq;
			next if ( ! defined ${$hash{$orgId}}[$var] );
			#print "\tVAR $var\n";
			#print "\tCHROMS",,"\n";
			$outStr .= ";" if ( defined $outStr );
			$outStr .= "$orgId.$var\{";

			if ( ! keys %{$hash{$orgId}[$var]} )
			{
			  #warn "NO CHROM :: $val\n";
			  print STDERR "\tNO CHROM :: \"$val\"\n";
			  return "";
			}

			foreach my $chrom ( keys %{$hash{$orgId}[$var]} )
			{
				#print "\t\tCHROM $chrom ", @{$hash{$orgId}[$var]{$chrom}} ,"\n";
				$outStr .= "$chrom\[";
				my $po1;

				if ( ! scalar(@{$hash{$orgId}[$var]{$chrom}}) )
				{
				  #warn "NO POS :: $val\n";
				  print STDERR "\tNO POS :: \"$val\"\n";
				  return "";
				}

				for (my $pos = 0; $pos < @{$hash{$orgId}[$var]{$chrom}}; $pos++ )
				{
		        		my $po = $hash{$orgId}[$var]{$chrom}[$pos];
					$po1  .= ":" if (defined $po1);
					$po1  .= $po;
				}
				$outStr .= "$po1]";
			}
			$outStr .= "}";
		} # end foreach my var
	} # end foreach my orgid

	if ( ! $outStr )
	{
	  #warn "NO OUTPUT :: \"$val\"\n";
	  print STDERR "\tNO OUTPUT :: \"$val\"\n";
	  return "";
	};

	return $outStr;
}

1;
