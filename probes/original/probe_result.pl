#!/usr/bin/perl -w
# Saulo Aflitos
# 2009 09 15 16 07
use strict;
#use DBI;
#TODO: CHANGE DOS FOR LOOP IN NEW

use threads;
use threads::shared;
use threads 'exit'=>'threads_only';

use lib "./filters";
#use complexity;
#use folding;
#use similarity;
#use dnaCode;
#use blast;
use loadconf;


my %pref = &loadconf::loadConf;
my $globalTimeStart = time;

#############################
### SETUP
#############################
	&loadconf::checkNeeds(
	"doTranslateFinalTable",	    "doCreateFinalTable",	    "doAnalyzeExtra",
	"statVerbose",			        "napTime",		    	    "maxThreads",
	"originalView",			        "originalTable",	    	"finalTable",
	"orderBy",			            "primaryKey",	    		"batchInsertions",
	"database",			            "reuse",	        		"blatFolder",
	"doCreateTmpTable", 		    "originalTablePK",      	"doCreateFinalTableFinal",
    "doPostProcessing",             "primaryKey",               "verbose");
	
	
	##### EXECUTION
	my $doCreateTmpTable                = $pref{"doCreateTmpTable"};			# create tmp table - complementar to reuse
	my $doAnalyzeFirst					= $pref{"doAnalyzeFirst"};	# do first step of analysis
	   my $doAnalyzeFirstQuasiBlast		= $pref{"doAnalyzeFirstQuasiBlast"};		# fragment distribution (rough local alignment - vector search engine google-like) #http://www.perl.com/lpt/a/713
	   my $doAnalyzeFirstBlat			= $pref{"doAnalyzeFirstBlat"};			# RUN EXTERNAL BLAT
	   my $doAnalyzeFirstComplexity		= $pref{"doAnalyzeFirstComplexity"};		# complexity and fold analysis
	   my $doAnalyzeFirstAlmostBlast	= $pref{"doAnalyzeFirstAlmostBlast"};	# almostBlast       (distance + contains/is contained by)
	   my $doAnalyzeFirstNWBlast		= $pref{"doAnalyzeFirstNWBlast"};		# blastNWIterate    (rough NeedlemanWunsch global alignment internal to selected ones)
	   my $doAnalyzeFirstNWBlastGlobal	= $pref{"doAnalyzeFirstNWBlastGlobal"};	# blastNWIterateTwo (rough NeedlemanWunsch global alignment against whole db)
	   my $doAnalyzeFirstBlatInput	    = $pref{"doAnalyzeFirstBlatInput"};	
	my $reuse           	  = $pref{"reuse"}; 			# table to reuse. undef to create a new table

	my $doAnalyzeExtra        = $pref{"doAnalyzeExtra"}; # do second step (TODO)

	my $doPostProcessing			= $pref{"doPostProcessing"};
	   my $doCreateFinalTable		= $pref{"doCreateFinalTable"};
	   my $doTranslateFinalTable	= $pref{"doTranslateFinalTable"};
	   my $doCreateFinalTableFinal	= $pref{"doCreateFinalTableFinal"};


#############################
### PROGRAM
#############################

if ( ! $reuse)
{
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	my $timeStamp      = sprintf("%04d%02d%02d%02d%02d", (1900+$year), ($mon+1), $mday, $hour, $min);
	$reuse = "NEW$timeStamp";
}


my %act;
if ($doCreateTmpTable)
{
	push(@{$act{"PRE"}}, $reuse);
}




if ($doAnalyzeFirst)
{
	#&sthAnalyzeFirst();	# analyze anything that can be done row by row.
						# update the table at the end automatically
						# threaded

	if ( $doAnalyzeFirstQuasiBlast    ) { push(@{$act{"FIRST"}}, "quasiblast"        ) };
	if ( $doAnalyzeFirstComplexity    ) { push(@{$act{"FIRST"}}, "AnalysisResult"    ) };
	if ( $doAnalyzeFirstBlat          ) { push(@{$act{"FIRST"}}, "externalBlat"      ) };
	if ( $doAnalyzeFirstAlmostBlast   ) { push(@{$act{"FIRST"}}, "almostBlast"       ) };
	if ( $doAnalyzeFirstNWBlast       ) { push(@{$act{"FIRST"}}, "blastNWIterate"    ) };
	if ( $doAnalyzeFirstNWBlastGlobal ) { push(@{$act{"FIRST"}}, "NWBlastGlobal"     ) };
	if ( $doAnalyzeFirstBlatInput     ) { push(@{$act{"FIRST"}}, "externalBlatInput" ) };
}

if ($doAnalyzeExtra)
{
	#&sthAnalyzeExtra(); # analyze anything that needs extra data handling
						# the update must be done individually
						# any threading must be done individually
	if ( $doAnalyzeExtra              ) { push(@{$act{"EXTRA"}}, "extra")      }
}


if ($doPostProcessing)
{
	#TODO: RE-STATE CORRECT LOGIC
	#if ( $doCreateFinalTable || $doTranslateFinalTable || $doCreateFinalTableFinal ) { push(@{$act{"POST"}}, "create"     ) };
	#if ( $doTranslateFinalTable  || $doCreateFinalTableFinal                       ) { push(@{$act{"POST"}}, "translate"  ) };
	if ( $doCreateFinalTable                                                       ) { push(@{$act{"POST"}}, "create"     ) };
	if ( $doTranslateFinalTable                                                    ) { push(@{$act{"POST"}}, "translate"  ) };
	if ( $doCreateFinalTableFinal                                                  ) { push(@{$act{"POST"}}, "finalfinal" ) };
}

print "ROOT: ACTIONS TO BE PERFORMED:\n";
foreach my $key  (qw (PRE FIRST EXTRA POST))
{
	my $action = $act{$key};
	next if ( ! defined $action );
	
	print "\t$key:\n";
	
	foreach my $part (@{$action})
	{
		print "\t\t$part\n";
	}
}

print "\n";

foreach my $key  (qw (PRE FIRST EXTRA POST))
{
	print $key, "\n";
	next if ( ! exists $act{$key});
	for (my $a = 0; $a < @{$act{$key}}; $a++)
	{	
		my $act = $act{$key}[$a];
		print "!!!!!!!! RUNNING :: ./probe_result_actuator.pl $reuse $key $act !!!!!!!!!!";
		open(ACTUATOR, "./probe_result_actuator.pl $reuse $key $act 2>&1|") or die "FAILED TO EXECUTE FIRST: $!";
		while ( my $line = <ACTUATOR> )
		{
			print $line;
			if (($line =~ /DBD error/) || ($line =~ /execute failed/))
			{
				die "DBD ERROR";
			}
			if ($line =~ /died at/)
			{
				die "EXECUTION ERROR";
			}
			if ($line =~ /FAILED/)
			{
				die "EXECUTION ERROR";
			}
			if ($line =~ /aborted due to compilation errors/)
			{
				die "COMPILATION ERROR";
			}
			if ($line =~ /terminated abnormally/)
			{
				die "THREAD ERROR";
			}
			
			
		}
		close ACTUATOR;
	}
}



print "SELECTION DONE. CONGRATS\n";
print "COMPLETION IN : ", (time-$globalTimeStart), "s\n";






1;
