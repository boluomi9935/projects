reset
rm binary.dat 2>/dev/null
rm binary.log 2>/dev/null

perl -e 'use binarytable; use getValues; my $it = binarytable->new( &getValues::getSetup() );'
ls -lh binary.*
