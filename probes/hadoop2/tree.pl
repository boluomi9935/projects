#!/usr/bin/perl -w
use strict;
use Tree::Trie;

my $trie = new Tree::Trie;
my @allnMuses = qw[aeode calliope clio erato euterpe melete melpomene mneme polymnia terpsichore thalia urania];
$trie->add(@allnMuses);
my @all       = $trie->lookup("");
my @ms        = $trie->lookup("m");
my @mOp       = $trie->lookup("m",10);
my @deleted   = $trie->remove(qw[calliope thalia doc]);
my @remaining = $trie->lookup("");

#$" = "--";

print "All muses                           : " , join(", ", @all)      , "\n";
print "Muses beginning with 'm'            : " , join(", ", @ms)       , "\n";
print "Options for muses beginning with 'm': " , join(", ", @mOp)      , "\n";
print "Deleted muses                       : " , join(", ", @deleted)  , "\n";
print "Remaining muses                     : " , join(", ", @remaining), "\n\n";

1;
