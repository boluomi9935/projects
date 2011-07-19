#!/usr/bin/perl -w
# Saulo Aflitos
# 2009 09 15 16 07
# TODO: DELETE THE DOs... LET THE XML DECIDE.. LET THE RESULT.PL DECIDE

use strict;
use warnings;
#use DBI;

use threads;
use threads::shared;
use threads 'exit'=>'threads_only';

use lib "./filters";
use DBIconnect;
use loadconf;

my %pref = &loadconf::loadConf;
my %vars;
my %outputColums;
my %analysis;

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
    "doPostProcessing",             "primaryKey",               "verbose",
    "extraColums");

	die "NO ARGUMENTS " if (@ARGV < 3);

	$vars{reusePref} = $pref{"reuse"}; 			# table to reuse. undef to create a new table
	$vars{reuseIn}   = $ARGV[0];
	$vars{PART}      = $ARGV[1];
	$vars{SUB}       = $ARGV[2];

	die "NO REUSE DEFINED" if ( ! defined $vars{reuseIn});
	die "NO PART  DEFINED" if ( ! defined $vars{PART});
	die "NO SUB   DEFINED" if ( ! defined $vars{SUB});


	if ($vars{reuseIn} =~ /^NEW(.*)/)
	{
		$vars{reuse}     = 0;
		$vars{timeStamp} = $1;
		print "CREATING NEW TMP TABLE $vars{timeStamp}\n";
	}
	else
	{
		$vars{reuse}     = 1;
		$vars{timeStamp} = $vars{reuseIn};
		print "CREATING NEW TMP TABLE $vars{timeStamp}\n";
	}

	print "REUSE $vars{reuse}\n";
	print "TIMESTAMP $vars{timeStamp}\n";


	$vars{blatFolder}            = $pref{"blatFolder"};
	$vars{blat_min_identity}     = $pref{"blat_min_identity"};
	$vars{blat_min_similarity}   = $pref{"blat_min_similarity"};


	##### EXECUTION
	$vars{doCreateTmpTable}               = $pref{"doCreateTmpTable"};	# create tmp table - complementar to reuse

	$vars{doAnalyzeFirst}				  = $pref{"doAnalyzeFirst"};	# do first step of analysis

	$vars{doAnalyzeExtra}			      = $pref{"doAnalyzeExtra"};    # do second step (TODO)

	$vars{doPostProcessing}			      = $pref{"doPostProcessing"};
	   $vars{doCreateFinalTable}		  = $pref{"doCreateFinalTable"};
	   $vars{doTranslateFinalTable}		  = $pref{"doTranslateFinalTable"};
	   $vars{doCreateFinalTableFinal}	  = $pref{"doCreateFinalTableFinal"};



# DECISION OF WHICH PART TO RUN
	$vars{doCreateTmpTable} 		      = 0;

	$vars{doAnalyzeFirst}   		      = 0;

	$vars{doAnalyzeExtra}                 = 0;
	   $vars{doAnalyzeExtra}		      = 0;

	$vars{doPostProcessing}               = 0;
	   $vars{doCreateFinalTable}		  = 0;
	   $vars{doTranslateFinalTable}	      = 0;
	   $vars{doCreateFinalTableFinal}     = 0;



	if ($vars{PART} eq "PRE")
	{
		$vars{doCreateTmpTable}  = 1;

		if (($vars{SUB} =~ /^NEW/) && ($vars{PART} eq "PRE"))
		{

		}
		elsif (($vars{SUB} =~ /^\d+$/) && ($vars{PART} eq "PRE"))
		{

		}
		else
		{
			die "NO VALID SUB SELECTION $vars{PART} :: $vars{SUB}";
		}

	}
	elsif ($vars{PART} eq "FIRST")
	{
		$vars{doAnalyzeFirst}    = 1;

		if    ($vars{SUB} eq "quasiblast"        ) { $vars{toRunThread} = "quasiblast"        ; }
		elsif ($vars{SUB} eq "externalBlat"      ) { $vars{toRunThread} = "externalBlat"      ; }
		elsif ($vars{SUB} eq "AnalysisResult"    ) { $vars{toRunThread} = "AnalysisResult"    ; }
		elsif ($vars{SUB} eq "almostBlast"       ) { $vars{toRunThread} = "almostBlast"       ; }
		elsif ($vars{SUB} eq "blastNWIterate"    ) { $vars{toRunThread} = "blastNWIterate"    ; }
		elsif ($vars{SUB} eq "NWBlastGlobal"     ) { $vars{toRunThread} = "NWBlastGlobal"     ;}
        elsif ($vars{SUB} eq "externalBlatInput" ) { $vars{toRunThread} = "externalBlatInput" ; }
		else  { die "NO VALID SUB SELECTION $vars{PART} :: $vars{SUB}"; }
	}
	elsif ($vars{PART} eq "EXTRA")
	{
		$vars{doAnalyzeExtra}    	= 1;

		if ($vars{SUB} eq "extra")
		{
			$vars{doAnalyzeExtra}	= 1;
		}
		else
		{
			die "NO VALID SUB SELECTION $vars{PART} :: $vars{SUB}";
		}
	}
	elsif ($vars{PART} eq "POST")
	{
		$vars{doPostProcessing}  = 1;

		if    ($vars{SUB} eq "create")	    { $vars{doCreateFinalTable}      = 1; }
		elsif ($vars{SUB} eq "translate")	{ $vars{doTranslateFinalTable}	 = 1; }
		elsif ($vars{SUB} eq "finalfinal")	{ $vars{doCreateFinalTableFinal} = 1; }
		else  {	die "NO VALID SUB SELECTION $vars{PART} :: $vars{SUB}"; }
	}
	else
	{
		die "NO GREAT ACT DEFINED";
	}


	print "REUSE ", $vars{reuse}, "\n";


	##### THREADING
	$vars{maxThreads}           = $pref{"maxThreads"};	# NUMBER OF THREADS
	$vars{napTime}              = $pref{"napTime"};		# SLEEP TIME BETWEEN EACH RETRY TO ADD NEW THREADS
	$vars{statVerbose}          = $pref{"statVerbose"};	# PRINT SUMMARY OF COLUMNS
    $vars{verbose}              = $pref{"verbose"};

	##### SQL DB
	$vars{originalView}         = $pref{originalView}; 	    # original     view  NAME   - origin of data
	$vars{intermediateTable}    = $pref{originalTable}; 	# intermediate table PREFIX - intermediate filter
	$vars{intermediateTable}   .= $vars{timeStamp};
	$vars{finalTable}           = $pref{finalTable}; 		# final        table NAME   - final result. equals to original view but filtered
	$vars{orderBy}              = $pref{orderBy}; 		    # ORDER BY    statement of final table
	$vars{primaryKey}           = $pref{primaryKey};		# PRIMARY KEY statement of final table

	$vars{database}             = $pref{"database"};		# mysql database
	$vars{batchInsertions}      = $pref{"batchInsertions"};	# number of batch insertions to the database

	$vars{originalTablePK}      = $pref{"originalTablePK"};						# PRIMARY OF ORIGINAL TABLE TO BE KEPT AROUND
	$vars{H_filterColums}       = &splitToHash($pref{"filterColums"});			# COLUMNS TO BE ANALIZED (IN GENERAL)

    foreach my $key (split(/,/, $pref{"extraColums"}))
    {
        push(@{$vars{A_extraColums}}, $key);
    }


#SELECT * FROM `probe`.`complete` GROUP BY `sequenceM13`, `ligant`,`sequenceLig`,`sequence` HAVING count(`sequence`)    = 1 AND HAVING count(`sequenceM13`) = 1 AND HAVING count(`ligant`) = 1 AND HAVING count(`sequenceLig`) = 1
#SELECT * FROM `probe`.`complete` GROUP BY `sequenceM13`,`ligant`,`sequenceLig`,`sequence` HAVING count(`sequence`) = 1 AND count(`sequenceM13`) = 1 AND  count(`ligant`) = 1 AND count(`sequenceLig`) = 1



#############################
### INITIALIZATION
#############################
$vars{addColumn}        = "";	# list of columns to add on intermediate table
$vars{insertInto}       = "";	# sql fragment to add values to new columns (automatic ones)
$vars{batchInsertions} -= 1;	# decrease by one so it's 0 based

#$vars{H_oldColumnIndex};	# original columns columns index
#$vars{H_newColumnIndex};	# new      columns columns index
#$vars{A_execution};		# execution order array with names [#] = $name





%analysis = &getAnalysisHash();
foreach my $analyzer (sort keys %analysis)
{
	my $mode        = $analysis{$analyzer}{mode};
	my $sqlName     = $analysis{$analyzer}{sqlField};
    my $active      = $analysis{$analyzer}{active};

    if ($active)
    {
        if (( ! defined $mode ) || ( ! $mode ))
        {
            $vars{insertInto} .=  ", " if ($vars{insertInto} ne "");
            $vars{insertInto} .=  "$sqlName = ?";
        }
    }
}

my $accValidation = "";
my @orderer;
my $lastOrder = 0;
foreach my $analyzer (sort keys %analysis)
{
    $orderer[$analysis{$analyzer}{order}] = $analyzer if (defined $analysis{$analyzer}{order});
}

foreach my $analyzer (sort keys %analysis)
{
    if ( ! defined $analysis{$analyzer}{order} && $analysis{$analyzer}{active})
    {
        push(@orderer, $analyzer);
    }
}


foreach my $analyzer (@orderer)
{
    die if ( ! defined $analyzer );
	my $sqlName     = $analysis{$analyzer}{sqlField};
	my $sqlType     = $analysis{$analyzer}{sqlType};
	my $sqlSize     = $analysis{$analyzer}{sqlSize};
	my $sqlOpt      = $analysis{$analyzer}{sqlOpt};
	my $validation  = $analysis{$analyzer}{validation};
	# EXECUTION
	my $mode        = $analysis{$analyzer}{mode};
	my $order       = $analysis{$analyzer}{order};
	my $function    = $analysis{$analyzer}{function};
	my $run         = $analysis{$analyzer}{run};
	my $displayName = $analysis{$analyzer}{name};
    my $active      = $analysis{$analyzer}{active};
    my $columns     = $analysis{$analyzer}{columns};
    my $colums;

    if ($active)
    {
        die if ( ! ((defined $sqlName) && (defined $sqlType) && (defined $sqlSize)) );

        $vars{H_newColumnIndex}{$sqlName} = undef;

        $vars{addColumn} .= ", ADD COLUMN $sqlName $sqlType";
        $vars{addColumn} .= " ($sqlSize)" if $sqlSize;
        $vars{addColumn} .= " $sqlOpt"    if $sqlOpt;

        if (defined $order)
        {
            die if ( ! ((defined $validation) && (defined $function) && (defined $displayName)) );

            if (defined $columns)
            {
                foreach my $key (split(/,/, $analysis{$analyzer}{columns}))
                {
                    push(@{$colums}, $key);
                }
            }

            $vars{A_execution}[$order]{name}            = $sqlName;
            $vars{A_execution}[$order]{validation}      = $validation;
            $vars{A_execution}[$order]{validation_in}   = $accValidation;
            $vars{A_execution}[$order]{function}        = $function;
            $vars{A_execution}[$order]{run}             = $run;
            $vars{A_execution}[$order]{displayName}     = $displayName;
            $vars{A_execution}[$order]{columns}         = $colums;
            $vars{A_execution}[$order]{analyzer}        = $analyzer;

            if ((( ! defined $mode ) || ( ! $mode )) && ( defined $order ))
            {
                $vars{A_execution}[$order]{"update"}    = $vars{insertInto} . " WHERE $vars{primaryKey} = ?";
                #print "NOT MODE ", ($displayName || 0), " ",($sqlName || 0)," ",($run || 0)," ",($order || 0)," ",($vars{A_execution}[$order]{update} || 0),"\n";
            }
            elsif ( defined $order )
            {
                $vars{A_execution}[$order]{"update"}    = "$sqlName = ? WHERE $vars{primaryKey} = ?";
                #print "MODE ", ($displayName || 0), " ",($sqlName || 0)," ",($run || 0)," ",($order || 0)," ",($vars{A_execution}[$order]{update} || 0),"\n";
            }

            my $outStr = "\tA_EXECUTION: \n\t\tORDER     : " . ($order         || 0) .
                                        "\n\t\tSQLNAME   : " . ($sqlName       || 0) .
                                        "\n\t\tDNAME     : " . ($displayName   || 0) .
                                        "\n\t\tCOLUMNS   : " . ($columns       || 0) .
                                        "\n\t\tVALIDATION: " . ($validation    || 0) .
                                        "\n\t\tACCVALIN  : " . ($accValidation || 0);
            print $outStr if ($vars{verbose});

            if    ($accValidation && $validation) { $accValidation .= " AND   $validation "; }
            elsif ($validation                  ) { $accValidation .= " WHERE $validation "; }
            else  {};

            print               "\n\t\tACCVALOUT : ", ($accValidation || 0),"\n\n"  if ($vars{verbose});

            $vars{A_execution}[$order]{validation_out}  = $accValidation;
        }
    }
}




$vars{A_execution} = &reorderArray(\@{$vars{A_execution}});

sub reorderArray
{
    my $array = $_[0];
    my $tmpArray;

    for (my $e = 0; $e < @{$array}; $e++)
    {
        if ( defined $array->[$e] )
        {
            push(@{$tmpArray}, ${$array}[$e]);
            #print "ADDING: ", ${$array}[$e]{displayName}, "\n";
        }
    }

    $array = $tmpArray;

    return $array;
}



#############################
### SQL STATEMENTS
#############################
## DECLARE MAIN TABLES
my $FROM_ORIGINAL_VIEW         = "\`$vars{database}\`.\`$vars{originalView}\`";
my $FROM_INTERMEDIATE_TABLE    = "\`$vars{database}\`.\`$vars{intermediateTable}\`";
my $FROM_CLEAN_TABLE           = "\`$vars{database}\`.\`$vars{finalTable}\`";
my $FROM_CLEAN_TABLE_TRANS     = "\`$vars{database}\`.\`$vars{finalTable}\_translated\`";
my $FROM_CLEAN_TABLE_FINAL     = "\`$vars{database}\`.\`$vars{finalTable}\_FINAL\`";

## DROP TABLES COMMANDS
my $commandDropCleanTable      = "DROP TABLE IF EXISTS $FROM_CLEAN_TABLE";
my $commandDropCleanTableTrans = "DROP TABLE IF EXISTS $FROM_CLEAN_TABLE_TRANS";
my $commandDropCleanTableFinal = "DROP TABLE IF EXISTS $FROM_CLEAN_TABLE_FINAL";

## SELECT/UPDATE ORIGINAL TABLE
my $selectOriginalView         = "SELECT * FROM $FROM_ORIGINAL_VIEW";  # SQL STATEMENT TO SELECT ALL RESULTS FROM INTERMEDIATE TABLE. GLOBAL
my $selectIntermediateTable    = "SELECT * FROM $FROM_INTERMEDIATE_TABLE"; # SQL STATEMENT TO SELECT ALL RESULTS FROM INTERMEDIATE TABLE. GLOBAL
my $updateOrignalTable         = "UPDATE $FROM_INTERMEDIATE_TABLE";        # SQL STATEMENT TO UPDATE INTERMEDIATE TABLE

my $commandGetAllResultsView   = "$selectOriginalView";
my $commandGetAllResults       = "$selectIntermediateTable";	# SQL STATEMENT TO GET ALL RESULTS
								# FROM INTERMEDIATE TABLE. POSSIBLE TO CHANGE AND FILTER
								# TODO: CHANGE TO JUST GET INTERESTING COLUMS !!URGENT!!







############################################
## SQL STATEMENT TO CREATE ORIGINAL TABLE
############################################
if ($vars{"doCreateTmpTable"})
{
	&sthAnalizeStat($commandGetAllResultsView . " LIMIT 1");	# get result from view table
    # to create tmp table, all information is needed
}
else
{
	&sthAnalizeStat($commandGetAllResults . " LIMIT 1");	# get result from intermediate table
    # to work with other tables, only information from intermediate table is needed
}




############################################
#SQL STATEMENT TO CREATE INTERMEDIARY TABLE
############################################
my $createQuery;
my $commandCreateTable;
my $commandAddColumn;


if ($vars{"doCreateTmpTable"} && ( ! $vars{reuse} ))
{
    $createQuery  = "SELECT * FROM ";
    $createQuery .= " (SELECT * FROM " x (scalar(keys %{$vars{H_filterColums}}) - 1);
    $createQuery .= " (SELECT " . join(", ", (sort keys %{$vars{H_filterColums}})) . ", $vars{originalTablePK}";

    foreach my $extra (@{$vars{A_extraColums}})
    {
        $createQuery .= ", $extra";
    }

	$createQuery .= " FROM $FROM_ORIGINAL_VIEW ";

	foreach my $filter (sort keys %{$vars{H_filterColums}})
	{
		$createQuery .= "GROUP BY $filter HAVING count($filter) = 1) AS t$filter ";
	}

    $commandCreateTable = "CREATE TABLE $FROM_INTERMEDIATE_TABLE ENGINE InnoDB $createQuery";	# SQL STATEMENT TO CREATE INTERMEDIATE TABLE
    $commandAddColumn   = "ALTER  TABLE $FROM_INTERMEDIATE_TABLE"                .		# SQL STATEMENT TO ADD NEW COLUMNS
                          " ADD COLUMN $vars{primaryKey} INT UNSIGNED NOT NULL AUTO_INCREMENT," .		# AND ID PRIMARY KEY TO INTERMEDIATE TABLE
                          " ADD PRIMARY KEY ($vars{primaryKey})$vars{addColumn}";
}


############################################
# GENERATING SEQUENCE SPECIFIC SQL STATEMENTS
############################################
my $createQueryFinalWhere;
my %sql;

for (my $e = 0; $e < @{$vars{A_execution}}; $e++)
{
	my $name = $vars{A_execution}[$e]{analyzer};

    die if ( ! defined $name);

	$sql{$name}{"name"}        = $vars{A_execution}[$e]{"name"};		                # COLUMN NAME
	$sql{$name}{"run"}         = $vars{A_execution}[$e]{"run"};						    # BOOLEAN RUN OR NOT
	$sql{$name}{"displayName"} = $vars{A_execution}[$e]{"displayName"};					# DISPLAY NAME
	$sql{$name}{"function"}    = $vars{A_execution}[$e]{"function"};					# REF TO FUNCTION TO BE CALLED
    $sql{$name}{"analyzer"}    = $vars{A_execution}[$e]{"analyzer"};					# REF TO FUNCTION TO BE CALLED
	$sql{$name}{"update"}      = $updateOrignalTable      . " SET " . $vars{A_execution}[$e]{"update"};	# UPDATE SQL STATEMENT
	$sql{$name}{"input"}       = $selectIntermediateTable . $vars{A_execution}[$e]{validation_in};		# INPUT SQL STATEMENT
    $sql{$name}{"result"}      = $selectIntermediateTable . $vars{A_execution}[$e]{validation_out};		# OUTPUT SQL STATEMENT
    $sql{$name}{"columns"}     = $vars{A_execution}[$e]{columns};		                                # COLUMNS TO BE USED

	# SQL STATEMENT TO GET THE FINAL VALID RESULTS (CONCATENATION OF ALL VALIDATIONS)
	$createQueryFinalWhere .= " AND " if (defined $createQueryFinalWhere);
	$createQueryFinalWhere .= $vars{A_execution}[$e]{validation};

	# GENERATING VALIDATION SQL STATEMENTS
	#if ($e == 0)
	#{
	#	$sql{$name}{"input"}  = $commandGetAllResults;
	#	$sql{$name}{"result"} = $sql{$name}{"input"} . " WHERE " . "$vars{A_execution}[$e]{validation_in}";
	#}
	#else
	#{
	#	for (my $f = 0; $f < $e; $f++)
	#	{
	#		$sql{$name}{"input"} .= "$vars{A_execution}[$f]{validation_in}";
	#		if ($f <= ($e-2)) { $sql{$name}{"input"} .= " AND " };
	#	}
    #	$sql{$name}{"input"} .= $vars{A_execution}[$e]{"validation"};
	#	$sql{$name}{"result"} = $sql{$name}{"input"} . " AND " . $vars{A_execution}[$e]{"validation"};
	#}
}




############################################
## GENERATE SQL STATEMENT TO CREATE CLEAN TABLE WITHOUT NEW COLUMNS
############################################
my $commandCreateFinalTable;
if ($vars{doCreateFinalTable})
{
       $commandCreateFinalTable       = "CREATE TABLE "          . $FROM_CLEAN_TABLE;
       $commandCreateFinalTable      .= " (PRIMARY KEY ("        . $vars{primaryKey}    . "))"	if ( defined $vars{primaryKey} );	# ADD PRIMARY KEY
       $commandCreateFinalTable      .= " ENGINE InnoDB";

    my $oldColumnsStr  = join(", ", map { $_ = "\`$vars{intermediateTable}\`.\`$_\`" }( sort keys %{$vars{H_filterColums}} ));
       $oldColumnsStr .= ", \`$vars{intermediateTable}\`.\`$vars{primaryKey}\` "   if ( defined $oldColumnsStr );


	if (defined $oldColumnsStr)
	{
		# SQL STATEMENT TO GENERATE FINAL TABLE CONTAININ ONLY THE ORIGINAL COLUMNS AND NOT THE ANALYSIS STEPS
		$commandCreateFinalTable .= " SELECT $oldColumnsStr";
	}
	else
	{
		$commandCreateFinalTable .= " SELECT \`$vars{intermediateTable}\`.\`*\`";
	}

    $commandCreateFinalTable      .= " FROM "                 . $FROM_INTERMEDIATE_TABLE;					                # FROM INTERMEDIARY TABLE

	if ( defined $createQueryFinalWhere )	# ADD WHERE STATEMENT CONTAINING ALL VALIDATIONS
	{
		$commandCreateFinalTable      .= " WHERE "                . $createQueryFinalWhere;
		#$commandCreateFinalTable      .= " AND ";
	}


    my $star                          = $oldColumnsStr;
}




############################################
## GENERATE SQL STATEMENT TO CREATE FINAL TABLE WITHOUT NEW COLUMNS
############################################
my $commandCreateFinalTableFinal;
if ($vars{doCreateFinalTableFinal})
{
    $commandCreateFinalTableFinal  =  "CREATE TABLE $FROM_CLEAN_TABLE_FINAL SELECT ";

    &sthAnalizeStat($commandGetAllResultsView . " LIMIT 1");	# get result table
    #&sthAnalizeStat($commandGetAllResults . " LIMIT 1");	# get result table

    my $hole_out;
    foreach my $o (sort keys %outputColums)
    {
        $hole_out .= ", " if ( defined $hole_out );
        $hole_out .= "\`" . $vars{originalView} . "\`.\`$o\`";
    }

    my $hole_filter;
    foreach my $n (sort keys %{$vars{H_filterColums}})
    {
        $hole_filter .= ", " if ( defined $hole_filter );
        $hole_filter .= "\`$vars{finalTable}\_translated\`.\`$n\`";
    }


    $commandCreateFinalTableFinal .= $hole_out . ", " . $hole_filter . ", " . "\`$vars{originalView}\`.\`$vars{originalTablePK}\`, \`$vars{finalTable}\_translated\`.\`$vars{primaryKey}\`";
    $commandCreateFinalTableFinal .= " FROM $FROM_ORIGINAL_VIEW, $FROM_CLEAN_TABLE_TRANS, $FROM_INTERMEDIATE_TABLE";
    $commandCreateFinalTableFinal .= " WHERE \`$vars{originalView}\`.\`$vars{originalTablePK}\` = \`$vars{intermediateTable}\`.\`$vars{originalTablePK}\`";
    $commandCreateFinalTableFinal .= " AND   \`$vars{intermediateTable}\`.\`$vars{primaryKey}\` = \`" . $vars{finalTable} . "\_translated\`.\`$vars{primaryKey}\`";
    $commandCreateFinalTableFinal .= " ORDER BY " . $vars{orderBy} if ( defined $vars{orderBy} );
}





############################################
## GENERATE SQL STATEMENT TO CREATE CLEAN_TRANSLATED TABLE
############################################
    my $commandCreateFinalTableTrans   = "CREATE TABLE $FROM_CLEAN_TABLE_TRANS LIKE          $FROM_CLEAN_TABLE";
    my $commandFillFinalTableTrans     = "INSERT INTO  $FROM_CLEAN_TABLE_TRANS SELECT * FROM $FROM_CLEAN_TABLE";

    my $commandGetAllFinalResults      = "SELECT * FROM $FROM_CLEAN_TABLE";
    my $commandGetAllFinalTransResults = "SELECT * FROM $FROM_CLEAN_TABLE_TRANS";
    my $commandUpdateFinalTableTrans   = "UPDATE        $FROM_CLEAN_TABLE_TRANS SET ";

    my $commandCheckFinalTable         = "SELECT * FROM $FROM_CLEAN_TABLE";

    #my $commandUpdateFinalTableCopy   = "UPDATE $FROM_CLEAN_TABLE_COPY SET ligant = ?, sequence = ?, sequenceLig = ?, sequenceM13 = ? WHERE $vars{primaryKey} = ?";
    #my $commandUpdateFinalTableCopy   = "UPDATE $FROM_CLEAN_TABLE_COPY SET ligant = \'<0>\', sequence = \'<1>\', sequenceLig = \'<2>\', sequenceM13 = \'<3>\' WHERE $vars{primaryKey} = \'<4>\'";


    my $commandUpdateLigants    = "$updateOrignalTable SET ligant = ? WHERE $vars{primaryKey} = ?";
    # TO DELETE

    # TO CHECK SQL STATEMENT
    # TO DELETE
    if (0)
    {
        foreach my $key (sort keys %sql)
        {
            print "KEY : ",$key,"\n";
            foreach my $SUB (keys %{$sql{$key}})
            {
                print "\t\t", $SUB,"\t",$sql{$key}{$SUB},"\n";
            }
        }

        die;
    }



#FINAL REPORT:
#SELECT * FROM finalProbes_FINAL, organism, chromossomes
#WHERE finalProbes_FINAL.idOrganism = CONCAT(organism.taxonid, ".", organism.variant)
#AND finalProbes_FINAL.chromossome = chromossomes.chromossomeNumber
#AND finalProbes_FINAL.idOrganism = chromossomes.idOrganism
#ORDER BY finalProbes_FINAL.idOrganism, finalProbes_FINAL.chromossome, finalProbes_FINAL.startLig


#CREATE TABLE test (PRIMARY KEY (idOrganism)) ENGINE InnoDB (SELECT idOrganism, count(*) FROM complete GROUP BY idOrganism)
#my $commandAddPrimaryKey     = "ALTER  TABLE         $FROM_CLEAN_TABLE  ADD PRIMARY KEY (Id)";

#print "_"x2, "COMMAND DROP FINAL TABLE   :\n\t", $commandDropCleanTable,   "\n";
#print "_"x2, "COMMAND CREATE FINAL TABLE :\n\t", $commandCreateFinalTable, "\n";
#print "COMMAND ADD PRIMARY KEY    :\n\t", $commandAddPrimaryKey,    "\n";











#############################
### PROGRAM
#############################

if ($vars{"doCreateTmpTable"})
{
	if ( ! $vars{reuse} )
	{
		# create table out of result view
		&sthInsertCreate($commandCreateTable, $commandAddColumn);
	}
	else
	{
		print "INSERT :: REUSING $vars{reuse} TABLE\n";
	}
}



if ($vars{"doAnalyzeFirst"})
{
	&sthAnalyzeFirst();	# analyze anything that can be done row by row.
						# update the table at the end automatically
						# threaded
}
elsif ($vars{"doAnalyzeExtra"})
{
	&sthAnalyzeExtra(); # analyze anything that needs extra data handling
						# the update must be done individually
						# any threading must be done individually
}
elsif ($vars{doPostProcessing})
{
	# creates table of good results from analyze first and extra
	if ($vars{doCreateFinalTable})	    { &sthInsertCreate($commandDropCleanTable, $commandCreateFinalTable);	}

	# translate table based on final table
	if ($vars{doTranslateFinalTable})   { &sthTranslateFinalTable($commandDropCleanTableTrans, $commandCreateFinalTableTrans, $commandFillFinalTableTrans, $commandGetAllFinalTransResults, $commandUpdateFinalTableTrans); }

	# generate final result with all original fields
	if ($vars{doCreateFinalTableFinal}) { &sthInsertCreate($commandDropCleanTableFinal, $commandCreateFinalTableFinal);	}
}
else
{
    print "NOTHING TO DO\n";
    exit 0;
}

$vars{statVerbose} = 0;
#&sthAnalizeStat($commandCheckFinalTable);
# create final table out of intermediate table


print "SELECTION DONE. CONGRATS\n";
print "COMPLETION IN : ", (time-$globalTimeStart), "s\n\n\n\n";












#############################
### SUBS
#############################
sub sthTranslateFinalTable()
{
	my $commandDrop   = $_[0];
	my $commandCreate = $_[1];
	my $commandFill   = $_[2];
#	my $commandModify = $_[2];
	my $commandGet    = $_[3];
	my $commandUpdate = $_[4];

	print "_"x2, "TRANSLATION :: DATABASE TRANSLATION\n";
	print "_"x4, "TRANSLATION :: DATABASE CREATION\n";

	print "_"x6, "TRANSLATION :: DROPPING OLD RESULT\n";
	&sthInsertCreate($commandDrop);
	print "_"x6, "TRANSLATION :: OLD RESULT DROPPED\n";

	print "_"x6, "TRANSLATION :: CREATING NEW TRANSLATED TABLE\n";
	&sthInsertCreate($commandCreate);
	print "_"x6, "TRANSLATION :: NEW TRANSLATED TABLE CREATED\n";

	print "_"x6, "TRANSLATION :: FILLING NEW TRANSLATED TABLE\n";
	&sthInsertCreate($commandFill);
	print "_"x6, "TRANSLATION :: NEW TRANSLATED TABLE FILLED\n";

#	print "_"x6, "TRANSLATION :: MODIFYING NEW TRANSLATED TABLE\n";
#	&sthInsertCreate($commandModify);
#	print "_"x6, "TRANSLATION :: NEW TRANSLATED TABLE MODIFIED\n";

	print "_"x6, "TRANSLATION :: GETTING NEW TRANSLATED TABLE INFO\n";
	&sthAnalizeStat($commandGet);
	print "_"x6, "TRANSLATION :: NEW TRANSLATED TABLE INFO ACQUIRED\n";



	print "_"x4, "TRANSLATION :: DATABASE CREATION SUCCESSFUL\n";
	print "_"x4, "TRANSLATION :: RETRIEVING RESULT\n";

	#my $dbh1 = DBI->connect("DBI:mysql:$vars{database}", $vars{user}, $vars{pw}, {RaiseError=>1, PrintError=>1, AutoCommit=>0}) or die "COULD NOT CONNECT TO DATABASE $vars{database} $vars{user}: $! $DBI::errstr";
    my $dbh1 = &DBIconnect::DBIconnect();
	my $sth1 = $dbh1->prepare($commandGet);
	$sth1->execute();

	my $rows = $sth1->rows;

	print "_"x6, "TRANSLATION :: ", $rows, " RESULTS RETRIEVED SUCCESSIFULLY\n";



	my $countRow    = 0;
	my $startTime   = time;

	my @translated;

	my $oldColumnIndex = $vars{H_oldColumnIndex}{$vars{primaryKey}};

	while(my $row = $sth1->fetchrow_arrayref)
	{
		$countRow++;

		print "_"x4, "TRANSLATION :: ACQUIRING ROW # $countRow\n" if ( ! ($countRow % (int ($rows / 5))));
		my @row     = @{$row};
		my $rowNum  = $row[$oldColumnIndex];
		my @cols;
		foreach my $keys (sort keys %{$vars{H_filterColums}}) {$cols[$vars{H_filterColums}{$keys}] = $keys };

		foreach my $colum (sort keys %{$vars{H_filterColums}})
		{
			my $index = $vars{H_filterColums}{$colum};

			$translated[$rowNum][$index] = &dnaCode::digit2dna($row[$index]);
			#print "ROW $rowNum COLUMN $colum SEQORIG $row[$index] SEQTRANS $translated[$rowNum][$index]\n";
		}
		#push(@{$translated[$rowNum]}, $rowNum);
	}
	$sth1->finish();
	$dbh1->commit();

	print "_"x4, "TRANSLATION :: DATA GATHERED TO TRANSLATION: ", (int((time - $startTime)+.5)), "s\n";

	print "_"x4, "TRANSLATION :: GENERATING BATCH INSERTION SCRIPT\n";
	my $queryStart   = time;
	my $countResults = 0;
	my @values;
	my $valuesP 	 = 0;
	my $valuesPzinho = 0;

	#TODO: use ADD instead of UPDATE !!URGENT!!
	open UPDATE, ">update.sql" or die "COULD NOT OPEN UPDATE.SQL";
	for (my $r = 0; $r < @translated; $r++)
	{
		if (defined $translated[$r])
		{
			my $tmp_update;
			foreach my $n (sort keys %{$vars{H_filterColums}})
			{
				my $index     = $vars{H_filterColums}{$n};
				$tmp_update .= ", " if ( defined $tmp_update );
				$tmp_update .= "$n = \'$translated[$r][$index]\'";
			}
			print UPDATE  $commandUpdate, " ", $tmp_update, " WHERE $vars{primaryKey} = $r;\n";
			#print         "$commandUpdate $tmp_update;\n";
		}
	}

	close UPDATE;

	my $mysqlCmd = $pref{mysqlCmd};
	print "_"x4, "TRANSLATION :: BATCH INSERTION SCRIPT CREATED : $valuesP ROUNDS OF INSERTIONS NEEDED\n";
	print "_"x4, "TRANSLATION :: INSERTING DATA\n";
	print "_"x6, "TRANSLATION :: time sudo $mysqlCmd < update.sql\n";

	print `time sudo $mysqlCmd < update.sql`;

	#for (my $r = 0; $r < @values; $r++)
	#{
	#	print "_"x4, "TRANSLATION :: INSERTING ROW # $countResults\n" if ( ! ($countRow % (int (@values / 20))));
	#	print $r, " ", $values[$r] , "\n";
#	#	my $updateFirstFh = $dbh1->prepare_cached($values[$r]);
	#	my $updateFirstFh = $dbh1->prepare($values[$r]);
	#	   $updateFirstFh->execute();
	#	   $updateFirstFh->finish();
	#	$countResults++;
	#}
	#$dbh1->commit();
	#$dbh1->disconnect();

	print "_"x4, "TRANSLATION :: UPDATE QUERY TIME : " , (time-$queryStart) , "s FOR ", $countResults," QUERIES\n";
	print "_"x4, "TRANSLATION :: TOTAL TIME : ", (int((time - $startTime)+.5)), "s\n";
	print "_"x2, "TRANSLATION :: TRANSLATION COMPLETED\n\n\n";

	return undef;
}







#######################################
####### CORE FUNCTIONS
#######################################
sub sthInsertCreate
{
	my $insertTime = time;
	my @commands   = @_;

	print "INSERT :: RUNNING COMMANDS\n";
	#my $dbhI = DBI->connect("DBI:mysql:$vars{database}", $vars{user}, $vars{pw}, {RaiseError=>1, PrintError=>1, AutoCommit=>0}) or die "INSERT :: COULD NOT CONNECT TO DATABASE $vars{database} $vars{user}: $! $DBI::errstr";
    my $dbhI = &DBIconnect::DBIconnect();

	foreach my $command (@commands)
	{
		print "\tINSERT :: RUNNING COMMAND : $command\n";
		$dbhI->do($command);
	}

	print "INSERT :: COMPLETED IN    : ", (time - $insertTime), "s\n";
	$dbhI->commit();
	$dbhI->disconnect();
}


sub sthAnalyzeFirst
{
	print "ANALIZE FIRST :: STARTING FIRST STEP OF ANALYSIS\n";

	# RUNS BY EXECUTION ORDER
	for (my $e = 0; $e < @{$vars{A_execution}}; $e++)
	{
		my $name = $vars{A_execution}[$e]{analyzer};
		next if ( ! defined $name );

		#if ($sql{$name}{run}) # for general
        if ($name eq $vars{SUB}) # for thread
		{
            print "\tANALYZER      : ", $sql{$name}{analyzer}    , "\n";
			print "\tDISPLAY NAME  : ", $sql{$name}{displayName} , "\n";
			print "\tFILLING COLUMN: ", $sql{$name}{name}        , "\n";
			print "\tINPUT         : ", $sql{$name}{input}       , "\n";
			print "\tUPDATE        : ", $sql{$name}{update}      , "\n\n";

			# EXECUTES THE REQUESTED FUNCTION SENDING
			$sql{$name}{function}->(
				$sql{$name}{name},  				    # NAME
				$sql{$name}{displayName},			    # THE DISPLAY NAME
				$sql{$name}{input},			    		# THE INPUT       SQL STATEMENT
				$sql{$name}{update},				    # THE UPDATE      SQL STATEMENT
				$commandGetAllResults,					# THE ALL RESULTS SQL STATEMENT
                $sql{$name}{columns},				    # COLUMNS TO BE ANALYZED
				\%pref,									# THE PREFERENCES
				\%vars);								# THE VARIABLES
		}
        else
        {
            #print "NOT RUNNING $name IN THIS THREAD\n";
        }
	}

	print "ANALIZE FIRST :: FIRST STEP OF ANALYSIS DONE\n";
}


sub sthAnalyzeExtra
{
	print "ANALIZE EXTRA :: STARTING SECOND STEP OF ANALYSIS\n";

	&sthGenerateLigants();
	&analyzeLigants();

	print "ANALIZE EXTRA :: SECOND STEP OF ANALYSIS DONE\n";
}







#######################################
####### SQL STATISTICAL/SETUP FUNCTIONS
#######################################
sub sthAnalizeStat
{
	my $command = $_[0];
	print "_"x2, "STAT :: RETRIEVING TABLE INFORMATION\n";
	print "_"x4, "STAT :: RETRIEVING RESULT: $command\n";
	#my $dbhS = DBI->connect("DBI:mysql:$vars{database}", $vars{user}, $vars{pw}, {RaiseError=>1, PrintError=>1, AutoCommit=>0}) or die "STAT :: COULD NOT CONNECT TO DATABASE $vars{database} $vars{user}: $! $DBI::errstr";
    my $dbhS = &DBIconnect::DBIconnect();

	my $sthS = $dbhS->prepare($command);
	$sthS->execute() or die "COULD NOT EXECUTE $command : $! : $DBI::errstr";
	print "_"x4, "STAT :: RESULT RETRIEVED SUCCESSIFULLY\n";

    $vars{H_newColumnIndex} = ();
    $vars{H_oldColumnIndex} = ();
    %outputColums           = ();

	# RETRIEVE THE TOTAL NUMBER OF FIELDS
	my $numOfFields = $sthS->{NUM_OF_FIELDS};
	my $numOfRows   = $sthS->rows;

	print "_"x6, "STAT :: RESULT : ", $numOfRows,   " ROWS RETRIEVED\n";
	print "_"x6, "STAT :: RESULT : ", $numOfFields, " COLUMNS FOUND\n";



	# GETS EACH COLUMN INDEX SO ONE CAN RETIEVE
	# ARRAY INSTEAD OF HASH
	my @fields;
	for (my $f = 0; $f < $numOfFields; $f++)
	{
		my $fieldName = $sthS->{NAME}->[$f];

		if (exists $vars{H_newColumnIndex}{$fieldName})
		{
			$vars{H_newColumnIndex}{$fieldName} = $f;
		}
		else
		{
			$vars{H_oldColumnIndex}{$fieldName} = $f;
		}
	}



	my $maxLen = 9;

	foreach my $key (sort keys %{$vars{H_oldColumnIndex}})
	{
		if ( $vars{H_oldColumnIndex}{$key} eq "" )
		{
			die "COULD NOT OBTAIN COLUM INDEX FOR $key";
		}
		$maxLen = length($key) if (length($key) > $maxLen);
	}


	foreach my $key (sort keys %{$vars{H_newColumnIndex}})
	{
		if ( ! defined $vars{H_newColumnIndex}{$key} )
		{
			print "COULD NOT OBTAIN COLUM INDEX FOR $key\n";
			next;
		}
		$maxLen = length($key) if (length($key) > $maxLen);
	}



	if ($vars{statVerbose})
	{
		print "_"x4, "STAT :: TOTAL COLUMNS : ", ((scalar keys %{$vars{H_oldColumnIndex}}) + (scalar keys %{$vars{H_newColumnIndex}})) , "\n";
		print "\tOLD\n";

		foreach my $col (sort keys %{$vars{H_oldColumnIndex}})
		{
			printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d", $col, $vars{H_oldColumnIndex}{$col};

			if (exists $vars{H_filterColums}{$col})
			{
				print " (*)";
				$vars{H_filterColums}{$col}       = $vars{H_oldColumnIndex}{$col};
			}
			elsif ($col eq $vars{originalTablePK})
			{
				print " (+)";
				#$vars{H_filterColums}{$col}       = $vars{H_oldColumnIndex}{$col};
			}
			else
			{
				print " (-)";
				$outputColums{$col} = $vars{H_oldColumnIndex}{$col};
			}

			print "\n";

			if ( ! (defined $vars{H_oldColumnIndex}{$col})) { die "NEW COLUMN $col NOT FOUND\n"; };
		}

		printf "\tNEW\n";

		foreach my $col (sort keys %{$vars{H_newColumnIndex}})
		{
			next if ( ! defined $vars{H_newColumnIndex}{$col} );
			printf "\t\t%-" . $maxLen . "s COLUMN INDEX = %02d\n", uc($col), $vars{H_newColumnIndex}->{$col};

			if ( ! (defined $vars{H_newColumnIndex}->{$col})) { die "NEW COLUMN $col NOT FOUND\n"; };
		}
	}
	die "STAT :: PROBLEM RETRIEVING TABLE $vars{database}", $sthS->errstr() ,"\n" if $sthS->err();

	$sthS->finish();
	$dbhS->commit();
	$dbhS->disconnect();
	print "_"x2, "STAT :: TABLE INFORMATION RETRIEVED\n\n\n";
}





#######################################
####### SQL COMMOM FUNCTIONS
#######################################
sub sthPrint
{
	my ($fields, $rows);
	($fields, $rows) = @_;
	foreach my $fieldname (@{$fields})
	{
		print "\t$fieldname\n";
	}

	foreach my $row (@{$rows})
	{
		print "\t" . join("  ", @{$row}) . "\n";
	}
}




sub sthExecute
{
	my @lists = @_;

	foreach my $sthE (@lists)
	{
		$sthE->execute();
		my $numOfFields = $sthE->{NUM_OF_FIELDS};
		#my @table       = @{$sthE->{'mysql_table'}};
		#print "TABLE HAS $numOfFields COLUMS\n\n";

		#print "register";
		my @fields;
		my @fieldSize;
		for (my $f = 0; $f < $numOfFields; $f++)
		{
			my $fieldName = $sthE->{NAME}->[$f];
			#print "$fieldName   ";
			push(@fields, $fieldName);
			$fieldSize[$f][0] = length($fieldName);
		}
		#print "\n";

		my $countRow = 1;

		my @values;
		while (my @row = $sthE->fetchrow_array())
		{
			#print "@row\n";
			#print $countRow++ . "\t";
			my @subVal;
			for (my $co = 0; $co < @row; $co++)
			{
				#print $row[$co] . "\t";
				push(@subVal, $row[$co]);
				$fieldSize[$co][0] = length($row[$co]) if (length($row[$co]) > $fieldSize[$co][0]);
				$fieldSize[$co][1] = ($row[$co] =~ /\D/) ? 1 : 0;
			}
			push(@values, \@subVal);
			#print "\n";
		}
		#print "\n"x2;
		warn "PROBLEM RETRIEVING TABLE $vars{database}", $sthE->errstr() ,"\n" if $sthE->err();

		if ($sthE->rows == 0)
		{
			print "NO NAMES MATCHED\n";
		}
		else
		{
			my $formatedF;
			my $formatedH;
			for (my $f = 0; $f < @fieldSize; $f++)
			{
				$formatedF .= "%";
				$formatedF .= $fieldSize[$f][1] ? "-" : "";
				$formatedF .= $fieldSize[$f][1] ? ($fieldSize[$f][0]+1) : ($fieldSize[$f][0]);
				$formatedF .= $fieldSize[$f][1] ? "s" : "d ";
				$formatedH .= "%-" . ($fieldSize[$f][0]+1) . "s";
			}

			printf "$formatedH", @fields;
			print "\n";

			for (my $f = 0; $f<@values; $f++)
			{
				printf "$formatedF", @{$values[$f]};
				print "\n";
			}
			print "\n\n";
		}
		$sthE->finish();
	}
}

sub splitToHash()
{
	my $str = $_[0];
	my %hash;
	foreach my $key (split(/,/, $str))
	{
		$hash{$key} = undef;
	}
	return \%hash;
}


sub getAnalysisHash
{
    my %ana;
    foreach my $key (sort keys %pref)
    {
        if ($key =~ /^NEW\.(.*)\.(.*)/)
        {
            my $analy = $1;
            my $field = $2;
            my $value = $pref{$key};

            if ($value)
            {
                while ($value =~ m/\<(.*?)\/\>/g)
                {
                    my $sub = $1;

                    if (exists $vars{$sub})
                    {
                        #print "SUB : $sub\n";
                        $value =~ s/\<$sub\/\>/$vars{$sub}/;
                    }
                    else
                    {
                        #print "NOT SUB : $sub\n";
                    }
                }
                $pref{$key} = $value;
            }

            #print "NEW $key :: ANALYSIS $analy : FIELD $field => ", ($value || "0"), "\n";

            if (($field eq "function") && ($value))
            {
                #similarity1_quasiblast::sthAnalizeSimilarity1
                my $func;
                my $use;
                my @package = split("::",$value);
                my $uStr = 'use filters::' .  $package[0];
                eval $uStr;
                die "ERROR EVALUATING USAGE $value PACKAGE $package[0] == $uStr : $@" if $@;

                my $fStr = '$func = \&' . "$value";
                eval $fStr;
                die "ERROR EVALUATING $value == $fStr : $@" if $@;

                print "\tLOADING DINAMIC MODULE : $value ... DONE\n";
                $ana{$analy}{$field} = $func;
            }
            else
            {
                $ana{$analy}{$field} = $value;
            }
        }
    }
    return %ana;
}

1;


#373.580 0:01.5382
#SELECT * FROM complete

#0:01.5796
#SELECT * FROM complete WHERE sequenceLig IN (SELECT sequenceLig FROM complete)

#283.887 0:00.3331
#SELECT sequenceLig FROM complete GROUP BY sequenceLig HAVING count(sequenceLig) = 1

#108.959 0:00.7939
#SELECT sequenceM13 FROM complete GROUP BY sequenceM13 HAVING count(sequenceM13) = 1

#278.165 0:00.2771
#SELECT ligant      FROM complete GROUP BY ligant      HAVING count(ligant) = 1

#303.636 0:02.3235
#SELECT * FROM complete GROUP BY sequence HAVING count(sequence) = 1

#crash after 4951 7:18.1314
#SELECT * FROM complete WHERE sequenceLig IN (SELECT sequenceLig FROM complete GROUP BY sequenceLig HAVING count(sequenceLig) = 1)

#102.046 0:02.0911
#SELECT * FROM (SELECT * FROM (SELECT * FROM complete GROUP BY sequenceM13 HAVING count(sequenceM13) = 1) as Tm13 GROUP BY ligant HAVING count(ligant) = 1) as Tligant GROUP BY sequenceLig HAVING count(sequenceLig) = 1

#102.046 0:02.5645
#SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM complete GROUP BY sequenceM13 HAVING count(sequenceM13) = 1) as Tm13 GROUP BY ligant HAVING count(ligant) = 1) as Tligant GROUP BY sequenceLig HAVING count(sequenceLig) = 1) AS Tlig  GROUP BY sequence HAVING count(sequence) = 1


#$listSeq, $listLig, $listM13, $listLiga
#my $avgSize       = int(($maxSize + $minSize)/2);
#my $guess         = int(&log10($listSize));
#my $wordLength    = $guess-(int($guess*.2));
#my $minAppearance = int(&log10($guess)+1.5);
#$wordLength = int(($avgSize * .3)) if (($avgSize * .3) > $wordLength);
#	PHRASES LIST SIZE: 102047 MINSIZE 21 MAXSIZE 30 AVGSIZE 25 WORD LENGTH: 7 MIN APPEARANCE: 2
#	WORD LIST SIZE: 608627
#	WC VALID: 600778 WC NON VALID: 7849 WC TOTAL: 608627
#	RESULT PHRASE VALID: 31408 RESULT PHRASE INVALID: 70639 TOTAL: 102047

#	PHRASES LIST SIZE: 102047 MINSIZE 9 MAXSIZE 14 AVGSIZE 11 WORD LENGTH: 4 MIN APPEARANCE: 2
#	WORD LIST SIZE: 423708
#	WC VALID: 416123 WC NON VALID: 7585 WC TOTAL: 423708
#	RESULT PHRASE VALID: 13037 RESULT PHRASE INVALID: 89010 TOTAL: 102047

#	PHRASES LIST SIZE: 102047 MINSIZE 13 MAXSIZE 17 AVGSIZE 15 WORD LENGTH: 4 MIN APPEARANCE: 2
#	WORD LIST SIZE: 536397
#	WC VALID: 526533 WC NON VALID: 9864 WC TOTAL: 536397
#	RESULT PHRASE VALID: 3245 RESULT PHRASE INVALID: 98802 TOTAL: 102047

#	PHRASES LIST SIZE: 102047 MINSIZE 8 MAXSIZE 8 AVGSIZE 8 WORD LENGTH: 4 MIN APPEARANCE: 2
#	WORD LIST SIZE: 253244
#	WC VALID: 219978 WC NON VALID: 33266 WC TOTAL: 253244
#	RESULT PHRASE VALID: 3294 RESULT PHRASE INVALID: 98753 TOTAL: 102047





#all fungi load
#start 1545
#end   1825
#total 0240
#580M data 833M index

#all fungi analysis - 3.2gb ram 4.3(threads)
#start 1827
#temp         3 min
#sim1        10 min
#compl      250 min (4h)
#end
#total      9861 (3h)


#	QUASIBLAST :: ANALIZING SIMILARITY
#		QUASIBLAST :: 1 : PHRASES LIST SIZE: 1665334 MINSIZE 9 MAXSIZE 14 AVGSIZE 12 WORD LENGTH: 4 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 1 : PHRASE VALID = 597392 PHRASE INVALID = 1067942 TOTAL PHRASES = 1665334
#		QUASIBLAST :: 2 : PHRASES LIST SIZE: 1665334 MINSIZE 13 MAXSIZE 17 AVGSIZE 15 WORD LENGTH: 5 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 2 : PHRASE VALID = 1665334 PHRASE INVALID = 0 TOTAL PHRASES = 1665334
#		QUASIBLAST :: 3 : PHRASES LIST SIZE: 1665334 MINSIZE 21 MAXSIZE 30 AVGSIZE 26 WORD LENGTH: 7 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 3 : PHRASE VALID = 1665334 PHRASE INVALID = 0 TOTAL PHRASES = 1665334
#		QUASIBLAST :: 4 : PHRASES LIST SIZE: 1665334 MINSIZE 8 MAXSIZE 8 AVGSIZE 8 WORD LENGTH: 3 MAX APPEARANCE: 2
#			QUASIBLAST :: RESULT : 4 : PHRASE VALID = 1665334 PHRASE INVALID = 0 TOTAL PHRASES = 1665334
#	QUASIBLAST :: VALID : 597391 INVALID : 1067942
#____SIMILARITY 1 :: VALID: 597392 INVALID: 1067942
#____SIMILARITY 1 :: UPDATE QUERY TIME : 148s FOR 1067942 QUERIES
#____SIMILARITY 1 :: TOTAL TIME : 567s

# NEW MATH
#	QUASIBLAST :: ANALIZING SIMILARITY
#		QUASIBLAST :: 1 : PHRASES LIST SIZE: 1665334 MINSIZE 9 MAXSIZE 14 AVGSIZE 12 WORD LENGTH: 4 MAX APPEARANCE: 4
#			QUASIBLAST :: RESULT : 1 : PHRASE VALID = 1296347 PHRASE INVALID = 368986 TOTAL PHRASES = 1665333
#		QUASIBLAST :: 2 : PHRASES LIST SIZE: 1665334 MINSIZE 13 MAXSIZE 17 AVGSIZE 15 WORD LENGTH: 5 MAX APPEARANCE: 4
#			QUASIBLAST :: RESULT : 2 : PHRASE VALID = 1292452 PHRASE INVALID = 3895 TOTAL PHRASES = 1296347
#		QUASIBLAST :: 3 : PHRASES LIST SIZE: 1665334 MINSIZE 21 MAXSIZE 30 AVGSIZE 26 WORD LENGTH: 9 MAX APPEARANCE: 5
#			QUASIBLAST :: RESULT : 3 : PHRASE VALID = 1292450 PHRASE INVALID = 2 TOTAL PHRASES = 1292452
#		QUASIBLAST :: 4 : PHRASES LIST SIZE: 1665334 MINSIZE 8 MAXSIZE 8 AVGSIZE 8 WORD LENGTH: 3 MAX APPEARANCE: 4
#			QUASIBLAST :: RESULT : 4 : PHRASE VALID = 0 PHRASE INVALID = 1292450 TOTAL PHRASES = 1292450
#	QUASIBLAST :: VALID : 0 INVALID : 1665333
