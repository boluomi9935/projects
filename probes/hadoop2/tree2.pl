#!/usr/bin/perl -w
#file://letrie.pl
#http://www.perlmonks.org/index.pl?node_id=175950

use strict;
$\="\n";
my $null = "\\NULL";
my %T=();

for my $word( qw/ aba abba abbda abbaracadabra bam bamara barbara saulo/ )
{
    print $word;

    my $R = \%T;
    my $C = -1;
    my( @word ) = $word =~ m{.}g;
    my $p = "";
    while (++$C < @word )
    {
        $p  = $word[$C];
        if( exists $R->{$p} )
        {
            if( ref $R->{$p} )
            {
                $R = $R->{$p};
            } else {
                $R = $R->{$p} = {};
            }
        } else {
            $R = $R->{$p} = {};
        }
    }

    $R->{$null} = 1; # for exact match testing
}#endof for


use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Purity    = 1;
$Data::Dumper::Quotekeys = 1;
print Dumper \%T;
print "Is 'abba' in a trie?  ",in_a_trie(\%T,'abba');
print "Is 'abbda' in a trie? ",in_a_trie(\%T,'abbda');
print "Is 'abbdr' in a trie? ",in_a_trie(\%T,'abbdr');
print "Is 'a' in a trie?     ",in_a_trie(\%T,'a');
print "Is 'b' in a trie?     ",in_a_trie(\%T,'b');
print "Is 'ba' in a trie?    ",in_a_trie(\%T,'ba');
print "Is 'bam' in a trie?   ",in_a_trie(\%T,'bam');
print "Is 'fsck' in a trie?  ",in_a_trie(\%T,'fsck');
print "Is 'sa' in a trie?    ",in_a_trie(\%T,'sa');
print "Is 'ul' in a trie?    ",in_a_trie(\%T,'ul');
exit;

sub in_a_trie {
    my( $T, $W ) = @_;
    my $R = 0;
    my $SH = "";

    for $SH ($W =~ m{.}g) {
        if(exists $T->{$SH} ) {
            $T = $T->{$SH};
            $R++;
        } else {
            return 'no';
        }
    }

    return ($R ? 'yes' : 'no').' '
          .(ref $T and $T->{$null} ? 'exact' : 'partial' );
}

#__DATA__
#
#aba
#abba
#abbda
#abbaracadabra
#bam
#bamara
#barbara
#$VAR1 = {
#  'a' => {
#    'b' => {
#      'a' => {
#        '\\NULL' => 1
#      },
#      'b' => {
#        'a' => {
#          '\\NULL' => 1,
#          'r' => {
#            'a' => {
#              'c' => {
#                'a' => {
#                  'd' => {
#                    'a' => {
#                      'b' => {
#                        'r' => {
#                          'a' => {
#                            '\\NULL' => 1
#                          }
#                        }
#                      }
#                    }
#                  }
#                }
#              }
#            }
#          }
#        },
#        'd' => {
#          'a' => {
#            '\\NULL' => 1
#          }
#        }
#      }
#    }
#  },
#  'b' => {
#    'a' => {
#      'm' => {
#        '\\NULL' => 1,
#        'a' => {
#          'r' => {
#            'a' => {
#              '\\NULL' => 1
#            }
#          }
#        }
#      },
#      'r' => {
#        'b' => {
#          'a' => {
#            'r' => {
#              'a' => {
#                '\\NULL' => 1
#              }
#            }
#          }
#        }
#      }
#    }
#  }
#};

