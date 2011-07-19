package getValues;
require Exporter;

@ISA       = qw{Exporter};
@EXPORT_OK = qw{getValues};

use strict;
use warnings;
#sub new {
#    my $class = shift;
#    my $self = bless {}, $class;
#    return $self;
#}

my $seqLeng    = 8;
my $bitsPerNuc = 2;
my $registers  = 3;

sub getSetup
{
    my $bitSize   = $seqLeng * $bitsPerNuc;
    my $tableSize = 2 ** $bitSize;
    printf "
**********************
* SEQ LENG    : %3d  *
* BITS PER NUC: %3d  *
* BIT SIZE    : %3d  *
* TABLE SIZE  : %3d  *
* REGISTERS   : %3d  *
**********************
", $seqLeng, $bitsPerNuc, $bitSize, $tableSize, $registers;

    my %setup = (
        bitSize           => $bitSize,   # int    : number of bit necessary to each field
        generateArray     => 1,    # boolean: generate array
        loadArrayFromFile => 0,    # boolean: load array from file
        logToFile         => 0,    # boolean: log output to file
        memory            => 0,    # boolean: 0=disk 1=memory
        numberRegisters   => $registers,    # int    : number of fields per cell
        printArray        => 0,    # boolean: print array table
        printArrayToFile  => 0,    # boolean: print array table to file or screen
        saveArraytoFile   => 1,    # boolean: save array to binary file
        systemBinarity    => 32,   # int    : 32 | 64
        tableSize         => $tableSize , # int    : table side
        verbose           => 1,    # boolean: verbosity 1-4
        function          => \&getValues,
    );


    return %setup;
}


sub getValues
{
    #my $self = shift;
    my $seq1 = $_[0];
    my $seq2 = $_[1];

    #my $maxValue = $self->{maxValue};
    die "SEQ 1 NOT DEFINED" if ! defined $seq1;
    die "SEQ 2 NOT DEFINED" if ! defined $seq2;
	my $compANDDec = (0+$seq1 & 0+$seq2);

    #my $seq1Bin    = &dec2bin($seq1);
    #my $seq2Bin    = &dec2bin($seq2);
	#my $compANDBin = &dec2bin($compANDDec);

    #$maxValue = $seq1       > $maxValue ? $seq1       : $maxValue;
    #$maxValue = $seq2       > $maxValue ? $seq2       : $maxValue;
    #$maxValue = $compANDDec > $maxValue ? $compANDDec : $maxValue;
    #
    #$self->{maxValue} = $maxValue;

    return [$seq1, $seq2, $compANDDec];
}

sub checkSubstitution
{

}


1;
