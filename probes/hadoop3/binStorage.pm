package binStorage;
require Exporter;

@ISA       = qw{Exporter};
@EXPORT_OK = qw{new retrieve finish append getSize  getSizeBytes convertBytes saveToFile loadFromFile};

use strict;
use warnings;
use varSize;

my $dataFile   = "binary.dat";
#my $buffer     = '';
my $bufferSize = 128 * (1024 * 1024);

sub new
{
    my $class = shift;
    my $self  = bless {}, $class;
    my %vars  = @_;
    #map { print "$_ => " . $vars{$_} . "\n"; } sort keys %vars;

    if ( ! exists $vars{method}    ) { $self->{method}    =  'memory' } else { $self->{method} = $vars{method} }; # memory or disk
    if ( ! exists $vars{fieldSize} ) { die "field size not defined" }; # number of bytes in each field

    $self->{fieldSize} = $vars{fieldSize};
    my $method = $self->{method};

    if ( $method eq 'memory' )
    {
        my $data   = '';
        $self->{data} = \$data;
    }
    elsif ( $method eq 'disk' )
    {
        my $buffer = '';
        $self->{buffer} = \$buffer;
        print "OPENING DAT $dataFile AND REDIRECTING MEMORY\n";
        #&openFh($self, 'write');
    } else {
        die "unknown method";
    }

    return $self;
}

sub retrieve
{
    my $self      = shift;
    my $method    = $self->{method};
    my $data      = $self->{data};
    my $fieldSize = $self->{fieldSize};
    my $start     = $_[0];
    my $length    = $_[1];
    my $out       = '';

    if ( $method eq 'memory' )
    {
        #print "\n";
        for (my $nc = 0; $nc < $length; $nc++)
        {
            my $val = vec($$data, $start+$nc, ($fieldSize*8));
            #print "\tABS COL POS $cellStartAbs+$nc = ".($cellStartAbs+$nc)." :: $val\n";
            vec($out, $nc, ($fieldSize*8)) = $val;
            print "\t\tSIZE ". varSize::getSize(\$out)."\n";
        }
    }
    elsif ( $method eq 'disk' )
    {
        my $fh      = &checkFh($self, 'read');
        my $begin   = ($start*$fieldSize);
        my $binLeng = ($fieldSize*$length);
        seek $fh, $begin, 0       or die "COULD NOT SEEK: $!";
        read $fh, $out, $binLeng, 0;
        #print "\t\tSIZE ". varSize::getSize(\$out)." START $start BEGIN $begin LENG $length BINLENG $binLeng\n";
    }

    return \$out;
}


sub getStat
{
    my $self = $_[0];

    &flush($self);
    return "" . $self->{appends} . " INSERTIONS PERFORMED";
}

sub flush
{
    my $self   = $_[0];

    if ( $bufferSize )
    {
        if ( $self->{method} eq 'disk' )
        {
            my $buffer = $self->{buffer};
            my $bSize  = &varSize::getSizeBytes($buffer);

            if ( $bSize )
            {
                print "FLUSHING " . &varSize::getSize($buffer). "\n";
                my $fh     = $self->{fh};
                print $fh $$buffer;
                $$buffer = '';
            }
        }
    }
}

sub append
{
    my $self   = shift;
    my $method = $self->{method};
    my $vec    = $_[0];

    $self->{appends}++;

    if ( $method eq 'memory' )
    {
        #print "ADDING ". &getSize(\$lVec) ." TO FH ".(&getSize(\$symArray))." ";
        my $data  = $self->{data};
          $$data .= $$vec;
        #print "" . (&getSize(\$symArray)) ." \n";
        return 0;
    }
    elsif ( $method eq 'disk' )
    {
        my $fh = &checkFh($self, 'write');
        use bytes;
        #print "ADDING ". &varSize::getSize($vec) ."\n";
        #seek  MEM, (($registerStart*$fieldSize)+$fieldSize), 0 or die "COULD NOT SEEK: $!";

        my $buffer = $self->{buffer};
        my $bSize  = &varSize::getSizeBytes($buffer);

        if ( $bufferSize )
        {
            if ( $bSize < $bufferSize )
            {
                #print "\tBUFFERING BUFF $bSize\n";
                $$buffer .= $$vec;
            } else {
                #print "\tDUMPING BUFF $bSize\n";
                $$buffer .= $$vec;
                &flush($self);
            }
        } else {
            print $fh $$vec;
        }

        return 0;
    }
    return 1;
}


sub checkFh
{
    my $self = shift;
    my $mode = $_[0];

    if ( ! exists $self->{fh} )
    {
        &openFh($self, $mode);
    }


   if ( exists $self->{fh} )
   {
       if ( (exists $self->{fhMode}) && ($self->{fhMode} ne $mode))
       {
            &closeFh($self);
            &openFh($self, $mode);
       }

       if ( (exists $self->{fhMode}) && ($self->{fhMode} eq $mode))
       {
            my $fh = $self->{fh};
            return $fh;
       } else {
           die "FAILED TO SET FILE HANDLE TO READ";
       }
   } else {
       die "FAILED TO OPEN FILE HANDLE";
   }
}
sub openFh
{
    my $self = shift;
    my $mode = $_[0];

    if ( exists $self->{fh} )
    {
        &flush($self);
        &closeFh($self);
    }

    if ( $mode eq 'write')
    {
        #print "DELETING $dataFile\n";
        unlink($dataFile);
    }

    #print "OPENING $dataFile TO $mode\n";
    my $arrow = $mode eq 'read' ? "<" : $mode eq 'write' ? ">" : die "unknown mode";
    open my $fh, "$arrow$dataFile" or die "COULD NOT OPEN MEMORY FILE $dataFile TO $mode: $!";
    binmode($fh);
    $self->{fh}     = $fh;
    $self->{fhMode} = $mode;
}

sub closeFh
{
    my $self = shift;

    if ( exists $self->{fh} )
    {
        #print "CLOSING $dataFile\n";

        my $fh = $self->{fh};

        &flush($self);

        close $fh or die "COULD NOT CLOSE FILE HANDLE";
        delete $self->{fh};
    };
    if ( exists $self->{fhMode} ) { delete $self->{fh}};
}

sub saveToFile
{
    my $self     = shift;
    my $method   = $self->{method};
    my $data     = $self->{data};
    my $fileName = $_[0];

    if ( $method eq 'memory ')
    {
        print "#"x20 . "\n";
        print "SAVING ARRAY\n";
        die "NO DATA" if ( ! defined $data );
        die "NO DATA" if ( ! length($$data) );
        #print "SAVING " . &getSize($dat) . "\n";
        print "#"x20 . "\n";
        my $outFile = ( defined $fileName ) ? $fileName : $dataFile;

        open DAT, ">$outFile" or die "COULD NOT OPEN DAT FILE $outFile: $!";
        binmode DAT;
        print DAT $$data;
        close DAT;

        die "ERROR SAVING DAT" if ( ! -s $outFile );
    }
}

sub loadFromFile
{
    my $self     = shift;
    my $method   = $self->{method};
    my $data     = $self->{data};
    my $fileName = $_[0];
    my $inFile   = ( defined $fileName ) ? $fileName : $dataFile;

    if ( $method eq 'memory ')
    {
        print "#"x20 . "\n";
        print "LOADING ARRAY\n";
        print "#"x20 . "\n";
        my $dat = '';
        open DAT, "<$inFile" or die "COULD NOT OPEN DATA FILE $inFile: $!";
        binmode DAT;
        my $buffer;
        while (
            read(DAT, $buffer, 65536) and $dat .= $buffer
            ){};
        close DAT;

        die "ERROR LOADING ARRAY FROM FILE" if ( ! length($dat));
        die "ERROR LOADING ARRAY FROM FILE" if ( ! defined $dat );
        #print "LOADED " . &getSize(\$dat) . "\n";

        return \$dat;
    }
}


sub getSize
{
    my $self = shift;

    my $method = $self->{method};
    my $size;

    if ( $method eq 'memory' )
    {
        $size = &varSize::getSize($self->{data});
    }
    elsif ( $method eq 'disk' )
    {
        if ( -f $dataFile )
        {
            $size = -s $dataFile;
            my $buffer = $self->{buffer};
            my $bSize  = &varSize::getSizeBytes($buffer);
            if ( $bSize ) { $size += $bSize; };
        } else {
            $size = 0;
        }
    }

    return $size;
}

#sub start
#{
#    my $self   = shift;
#    my $method = $self->{method};
#    my $data   = $self->{data};
#
#	if ( $method eq 'disk' )
#	{
#		open MEM, "<$dataFile" or die "COULD NOT OPEN DATA FILE $dataFile: $!";
#		binmode MEM;
#	}
#}

#sub finish
#{
#    my $self   = shift;
#    my $method = $self->{method};
#    my $data   = $self->{data};
#
#	if ( $method eq 'disk' )
#	{
#		&closeFh($self);
#	} else {
#        if ( ! defined $data )
#        {
#            die "ERROR GENERATING ARRAY";
#        }
#    }
#
#    print "STORAGE CLOSED :: " . &getStat($self) . "\n";
#}
1;
