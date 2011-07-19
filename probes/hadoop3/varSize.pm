package varSize;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


sub getSize
{
	my $var   = $_[0];
	my $bytes =  &getSizeBytes($var);

	my ($size, $unity)  = &convertBytes($bytes);
	return "$size $unity";
}

sub convertBytes
{
	my $bytes = $_[0];
	my $size;
	my $unity;

	my $kb = 1024;
	my $mb = $kb * 1024;
	my $gb = $mb * 1024;

	if ( $bytes >= $gb )
	{
		$size = $bytes / $gb;
		$unity = "Gb";
	}
	elsif ( $bytes >= $mb )
	{
		$size = $bytes / $mb;
		$unity = "Mb";
	}
	elsif ( $bytes >= $kb )
	{
		$size = $bytes / $kb;
		$unity = "Kb";
	} else {
		$size = $bytes;
		$unity = "bytes";
	}

	#if ( $unity ne 'bytes' )
	#{
		$size = sprintf("%.2f", $size);
	#}

	return ($size, $unity);
}

sub getSizeBytes
{
	my $var = $_[0];

    if ( defined $var )
    {
        if ( $var eq 'file' )
        {
            if ( defined $_[1] )
            {
                if ( -f $_[1] )
                {
                    return -s $_[1];
                } else {
                    return 0;
                }
            } else {
                return -1;
            }
        } else {
            use bytes;
            if ( ref($var) eq 'REF' )
            {
                #print "<REF> ".ref($var)." " . length($$var) ."\n";
                return length($$var);
            }
            elsif ( ref($var) eq 'SCALAR' )
            {
                #print "<REF> ".ref($var)." " . length($$var) ."\n";
                return length($$var);
            }
            else
            {
                #print "<VAR>".ref($var)." " . length($var) ."\n";
                return length($var);
            }
        }
    } else {
        return -1;
    }

	return -1;
}



1;
