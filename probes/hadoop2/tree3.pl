#!/usr/bin/perl -w
#file://letrie.pl
#http://www.perlmonks.org/index.pl?node_id=175950
#http://blog.afterthedeadline.com/2010/01/29/how-i-trie-to-make-spelling-suggestions/

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

    $R->{$null} = $word; # for exact match testing
}#endof for


use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Purity    = 1;
$Data::Dumper::Quotekeys = 1;
#print Dumper \%T;

for my $word ( qw/sa ul/ )
{
    printf "Is '%-5s' in a trie?  BEGIN: %-11s ANY:\n", $word, in_a_trie_start(\%T,$word);
    my $mpty = {};
    print  " "x47, join("\n". " "x47, in_a_trie_any(\%T, $word, $mpty, 2)), "\n";
}

exit;


sub in_a_trie_any {
    my( $trie, $word, $results, $depth ) = @_;

    print "  "x$depth    , "WORD \"$word\" DEPTH \"$depth\"\n";
    print "  "x($depth+4), "TRIE    :: ", Dumper $trie;
    print "\n", "--"x30 . "\n";
    print "  "x($depth+4), "RESULTS :: ", Dumper $results;
    print "\n", "=="x30 . "\n\n\n";

    my $branch = '';
    my $letter = '';
    my $root   = '';

    if ( length($word) == 0 && $depth >=0 && exists $trie->{$null} && $trie->{$null} ne '')
    {
        $results->{$trie->{$null}} = 1;
    }

    if ( $depth >= 1 )
    {

		# deletion. [remove the current letter, and try it on the current branch--see what happens]
		if (length $word > 1) {
			in_a_trie_any($trie, substr($word, 1), $results, $depth - 1);
		}
		else {
			in_a_trie_any($trie, "", $results, $depth - 1);
		}

		for $letter ( keys %$trie )
        {
            if ( $letter eq $null ) { next; }
            $branch = $trie->{$letter};

			# insertion. [pass the current word, no changes, to each of the branches for processing]
			in_a_trie_any($branch, $word, $results, $depth - 1);

			# substitution. [pass the current word, sans first letter, to each of the branches for processing]
			if ( length $word > 1)
            {
				in_a_trie_any($branch, substr($word, 1), $results, $depth - 1);
			} else {
				in_a_trie_any($branch, "", $results, $depth - 1);
			}
		}

		# transposition. [swap the first and second letters]
		if ( ( length $word) > 2 )
        {
			in_a_trie_any($trie, substr($word, 1,1) . substr($word, 0,1) . substr($word, 2), $results, $depth - 1);
		}
        elsif ((length $word) == 2)
        {
			in_a_trie_any($trie, substr($word, 1,1) . substr($word, 0,1), $results, $depth - 1);
		}
	}

	# move on to the next letter. (no edits have happened)

	if ((length $word) >= 1 && exists $trie->{substr($word, 0,1)})
    {
		$letter = substr($word, 0,1);
		if ((length $word) > 1)
        {
			in_a_trie_any($trie->{$letter}, substr($word, 1), $results, $depth);
		}
		elsif ((length $word) == 1) {
			in_a_trie_any($trie->{$letter}, "", $results, $depth);
		}
	}

	# results are stored in a hash to prevent duplicate words
	return (keys %$results);
}


sub in_a_trie_start {
    my( $T, $W ) = @_;
    my $R  = 0;
    my $SH = "";

    for $SH ($W =~ m{.}g)
    {
        if( exists $T->{$SH} )
        {
            $T = $T->{$SH};
            $R++;
        } else {
            return 'no';
        }
    }

    return ($R ? 'yes' : 'no').' '
          .(ref $T and $T->{$null} ? 'exact' : 'partial' );
}


sub in_a_trie_start_orig {
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

