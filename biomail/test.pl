#!/usr/bin/perl -w
use warnings;
use strict;
use File::Find;
use File::Basename;

my $here     = `pwd`;
chomp $here;
chomp $here;

my @files;
find (sub { push (@files, "$File::Find::name$/") if (( $_ =~ /(.*)\.pm$/i ) && ( $File::Find::dir eq "$here/progs" )) }, "$here/progs");
# find (sub { push (@files, "$File::Find::name$/") if (( $_ =~ /(.*)\.pm$/i ) && ( ! ( $File::Find::name =~ /lib/ ))) }, "./progs");
# lists all pm files under ./progs dir

map { chomp } @files;
print join("\n", @files);
print "\n";

1;