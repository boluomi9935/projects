#!/usr/bin/perl
use strict;
use warnings;

my $bucket = "probe";
my $folder = "output2";
my $pubKey = "pub";
my $priKey = "pri";
my $inFile = "files.list";

my $dependencies = 0;
my $download     = 0;
my $upload       = 1;

my %files;

if ( $dependencies )
{
    print "INSTALLING DEPENDENCES\n";
    print `yum -y install curl`;
    print `yum -y install screen`;
    print "DEPENDENCES INSTALLED\n\n";
}

print "SETTING AWS\n";
if ( ! -f "./aws" )
{
    print `curl timkay.com/aws/aws -o aws`;
    print `chmod +x aws`;

    `echo "$pubKey" > ~/.awssecret`;
    `echo "$priKey" >> ~/.awssecret`;

    `echo "" >> ~/.awssecret`;
    `chmod g-r ~/.awssecret`;
    `chmod g-w ~/.awssecret`;
    `chmod o-r ~/.awssecret`;

	`echo "<CreateBucketConfiguration>" > eu.xml`
	`echo "  <LocationConstraint>EU</LocationConstraint>" >> eu.xml`
	`echo "</CreateBucketConfiguration>" >> eu.xml`
	`echo "" >> eu.xml`
}
print "AWS SETED UP\n\n";

print "GETTING FILE LIST\n";
if ( ! -f "files.list" )
{
    my $command = "./aws ls $bucket | gawk \'\{print \$7\}\' | grep $folder | grep -v \"folder\" > $inFile";
    print "RUNNING $command\n";
    `$command`;
}
print "FILE LIST OBTAINED\n\n";


if ( ! -f $inFile ) { die "INFILE $inFile DOESNT EXISTS\n"};


open FILE, "<$inFile" or die "COULD NOT OPEN IN FILE $inFile: $!";
while (my $line = <FILE>)
{
    chomp $line;
    if ($line =~ /\.gz/)
    {
        $files{gz}{$line} = 1;
    }
    else
    {
        $files{in}{$line} = 1;
        print "FILE $line SET TO BE PROCESSED\n";
    }
}
close FILE;

print "\n", scalar(keys %files), " FILES TO BE PROCESSED\n";


foreach my $line (sort keys %{$files{in}})
{
    print "$line\n"; 

    my $name = substr($line,rindex($line, "/")+1); 
    print "PROCESSING $name... ";

    if ( ( ! -f $name ) && ( $download ) )
    { 
        print "DOWNLOADING $name... "; 
        `./aws get --progress $bucket/$line $name`; 
        #system("./aws get $bucket/$line $name"); 
    } 

    if ( -f $name ) 
    { 
        if ( ! -f "shared-$name" )
        {
             print "SHARED... "; 
             `cat $name \| grep \",\" > shared-$name`; 
             #system("cat $name \| grep \",\" > shared-$name"); 
        }

        if ( ! -f "shared-$name.gz" )
        {
            print "ZIP... "; 
            `gzip -5 shared-$name`; 
            #system("gzip -5 shared-$name"); 
        }

        if ( ! -f "unique-$name" )    
        {
            print "UNIQUE... "; 
            `cat $name \| grep -v \",\" > unique-$name`; 
            #system("cat $name \| grep -v \",\" > unique-$name"); 
        }

        if ( ! -f "unique-$name.gz" )
        {
            print "ZIP... "; 
            `gzip -5 unique-$name`; 
            #system("gzip -5 unique-$name"); 
        }
    }

    if ( ! $upload ) { print "DONE\n"; next; };

    if (( -f "shared-$name.gz" ) && ( -f "unique-$name.gz" ) )
    {
       if ( ( ! exists $files{gz}{"$folder/shared-$name.gz"} ) && ( ! exists $files{gz}{"$folder/unique-$name.gz"} ) )
       {
            print "SENDING shared-$name.gz ... "; 
            `./aws put --progress $bucket/$folder/shared-$name.gz shared-$name.gz`;

            print "SENDING unique-$name.gz ... ";
            `./aws put --progress $bucket/$folder/unique-$name.gz unique-$name.gz`;
        }
        else
        {
            print "GZ FILES ALREADY ON SERVER... ";
        }
     }
     else
     {
         print "NO GZ FILES... ";
     }

     print "DONE\n";
}

print "FILE $inFile PROCESSED\n";

1;
