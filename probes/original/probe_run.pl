#!/usr/bin/perl -w
use strict;
use Cwd;
#use lib "./filters";
use filters::loadconf;
use filters::toolsOO;
my %pref = &loadconf::loadConf;

my $sleepActuator = 30;
my $tools         = toolsOO->new();

#$pref{""}

#COMPACT
#$ time mysql -uroot -pcbscbs12 < Linkprobes/input/allatonce.sql
#real	62m57.451s
#user	3m8.156s
#sys	0m15.035s
#$ time mysql -uroot -pcbscbs12 < sql/probe_9_index.sql
#real	173m55.408s
#user	0m0.006s
#sys	0m0.002s

#DYNAMIC POSID AS INDEX
#$ time mysql -uroot -pcbscbs12 < Linkprobes/input/allatonce.sql
#real	49m40.741s
#user	3m9.401s
#sys	0m15.228s
#$ time mysql -uroot -pcbscbs12 < sql/probe_9_index.sql
#real	120m44.778s
#user	0m0.005s
#sys	0m0.000s



#TODO:
# - check whether it's better to join all sql or send them as *.sql
# - check whether it's faster to add each key one-by-one or in a single statement
# - check whether it's better to creat a non-compressed table, insert data, create the keys and then compress the table

####### SETUP
&loadconf::checkNeeds(
"currentDir",                "indir",                  "storageDir",                "optRate",
"inserts",                   "mysqlCmd",               "cleanUpStorageDirInputAll", "cleanUpStorageDirInputDid",
"cleanUpStorageDirInputSql", "cleanUpStorageDirDumps", "sqlDrop",                   "sqlCreate",
"sqlFlush",                  "probeResultScript",      "probeExtractorScript",      "probeActuatorScript",
"probeActuatorBash",         "probeInputScript",       "storageDirInput",           "storageDirInput",
"sqlDropScript",             "sqlFlushScript",         "sqlOptScript",              "sqlStartScript",
"sqlIndexScript",            "indirTaxonomyFile");

my $currentDir           		= $pref{"currentDir"};
my $indir                		= $pref{"indir"};
my $storageDir 					= $pref{"storageDir"};
my $optRate              		= $pref{"optRate"}; # optize each nn analysis
my $inserts              		= $pref{"inserts"}; # number of concurrent probe search and insertions
my $mysqlCmd             		= $pref{"mysqlCmd"};

my $cleanUpStorageDirInputAll	= $pref{"cleanUpStorageDirInputAll"};	#delete all files on storagedir
my $cleanUpStorageDirInputDid	= $pref{"cleanUpStorageDirInputDid"};	#delete all previous analized files on storagedir
my $cleanUpStorageDirInputSql	= $pref{"cleanUpStorageDirInputSql"};	#delete all files yet to be analyzed on storagedir
my $cleanUpStorageDirDumps		= $pref{"cleanUpStorageDirDumps"};		#delete all dump files on storagedir

my $sqlDrop						= $pref{"sqlDrop"};		#drop sql database
my $sqlCreate					= $pref{"sqlCreate"};	#create sql database
my $sqlFlush					= $pref{"sqlFlush"};	#flush sql database
my $sqlDatabase					= $pref{"database"};	#sql database to store data
my $sqlUser						= $pref{"user"};		#sql user to login

my $probeResultScript			= $pref{"probeResultScript"};
my $probeExtractorScript		= $pref{"probeExtractorScript"};
my $probeActuatorScript			= $pref{"probeActuatorScript"};
my $probeActuatorBash			= $pref{"probeActuatorBash"};	#DINAMICALLY GENERATED
my $probeInputScript			= $pref{"probeInputScript"};

my $storageDirInput				= $pref{"storageDirInput"};
my $storageDirDumps				= $pref{"storageDirDumps"};
my $sqlDropScript				= $pref{"sqlDropScript"};
my $sqlFlushScript				= $pref{"sqlFlushScript"};
my $sqlOptScript				= $pref{"sqlOptScript"};
my $sqlStartScript				= $pref{"sqlStartScript"};
my $sqlIndexScript              = $pref{"sqlIndexScript"};
my $indirTaxonomyFile			= $pref{"indirTaxonomyFile"};	#IN ADITION TO INDIR

######## INITIATION

my $probeResultCmd       = "time " . $probeResultScript;

######## CHECK FILES AND DIR
&checkSetup();

#&mkBashThread($basedir,   $listdir,         $extension, $runname,		$outputfile,        $action);
&mkBashThread($currentDir, $storageDirDumps, "xml",		"runactuator",	$probeActuatorBash, \&getActuatorAction, \&getActuatorActionPos); #actuator
#&mkBashThread($storageDir, $storageDirInput, "sql",		"run",			$probeInputScript,  \&getInsertAction,   \&getInsertActionPos);   #insert

######## CHEK FOLDER
opendir (DIR, "$indir") or die $!;
my @infiles = grep /\.fasta$/, readdir(DIR);
closedir DIR;
$| = 1;

if ( ! @infiles ) { die "NO FASTA FILES FOUND IN $indir DIRECTORY"};

my %taxonomy;
$tools->getTaxonomy($indirTaxonomyFile, \%taxonomy);



######## CLEANUP
if ($cleanUpStorageDirInputAll) { `rm -f $storageDirInput/* 2>/dev/null`;     }; #delete all files on storagedir
if ($cleanUpStorageDirInputDid) { `rm -f $storageDirInput/*.did 2>/dev/null`; }; #delete all previous analized files on storagedir
if ($cleanUpStorageDirInputSql) { `rm -f $storageDirInput/*.sql 2>/dev/null`; }; #delete all files yet to be analyzed on storagedir
if ($cleanUpStorageDirDumps)    { `rm -f $storageDirDumps/* 2>/dev/null`;     }; #delete all dump files on storagedir

if ($sqlDrop)#drop sql database
{
	print "SQL:: TRYING TO DROP TABLE\n";
	my $error = `$sqlDropScript`;
	if ($error) { die "\tSTATEMENT FAILED:\n\t\t$error"};
	$sqlCreate = 1;
};

if ($sqlCreate) #create sql database
{
	print "SQL:: TRYING TO RE CREATE TABLE\n";
	my $error = `$sqlStartScript`;
	if ($error) { die "\tSTATEMENT FAILED:\n\t\t$error"};
};

if ($sqlFlush) #flush sql database
{
	print "SQL:: TRYING TO FLUSH TABLE\n";
	my $error = `$sqlFlushScript`;
	if ($error) { die "\tSTATEMENT FAILED:\n\t\t$error"};
};


######## SCRIPT CREATION
my $cFile = 0;


my $actuatorResult  = "echo \"" . "."x20 . "\"\n";
   $actuatorResult .= "echo RUNNING ACTUATOR ON RESULT\n";
   $actuatorResult .= "echo \"" . "."x20 . "\"\n";
   $actuatorResult .= "$probeActuatorBash &\n";
   $actuatorResult .= "sleep $sleepActuator\n\n\n";

my $insertResult    = "echo \"" . "."x20 . "\"\n";
   $insertResult   .= "echo INSERTING RESULT\n";
   $insertResult   .= "echo \"" . "."x20 . "\"\n";
   $insertResult   .= "$probeInputScript\n\n\n";

my $opt             = "echo \"" . "."x20 . "\"\n";
   $opt            .= "echo OPTIMIZING DATABASE\n";
   $opt            .= "echo \"" . "."x20 . "\"\n";
   $opt            .= "time sudo $mysqlCmd < $sqlOptScript\n\n";

my $probeResult     = "echo \"" . "."x20 . "\"\n";
   $probeResult    .= "echo ANALIZING RESULT\n";
   $probeResult    .= "echo \"" . "."x20 . "\"\n";
   $probeResult    .= "$probeResultCmd\n\n\n";

my $indexResult     = "echo \"" . "."x20 . "\"\n";
   $indexResult    .= "echo INSERTING INDEX TO SQL TABLE\n";
   $indexResult    .= "echo \"" . "."x20 . "\"\n";
#   $indexResult    .= &getIndexScript() . "\n\n\n";


my $fileOut = "#!/bin/sh\n";


$fileOut .= "echo \"" . ":"x40 . "\"\n";
$fileOut .= "echo \"RUNNING OVER " . scalar(@infiles) . " FILES:\"\n";
my $countFile = 0;
foreach my $file (sort @infiles)
{
	if (exists $taxonomy{$file})
	{
		$fileOut .= sprintf("echo \"\t%0".(length @infiles)."d \'%s\'\"\n",++$countFile,$file);
	}
	else
	{
		die "FASTA FILE $file NOT IN TAXONOMY FILE\n: $!";
	}
}
$fileOut .=  "echo \"" . ":"x40 . "\n\n\"\n\n";










foreach my $file (sort @infiles)
{
	$cFile++;
	$fileOut .=  "echo \"" . "#"x20 . "\"\n";
	$fileOut .=  "echo \"RUNNING FILE $cFile OUT OF " . scalar(@infiles) . "\t$file\"\n";
	$fileOut .=  "echo \"" . "#"x20 . "\"\n";

	if ( !($cFile % $optRate)) { print FILE $opt; };
	my $taxonId      = $taxonomy{$file}[0];
	my $variant      = $taxonomy{$file}[1];
	my $sequenceType = $taxonomy{$file}[2];
	my $command      = "time $probeExtractorScript $indir $file $taxonId $variant $sequenceType ";

	$fileOut .=  "$command\n";

	$fileOut .=  "echo \"" . "*"x20 . "\"\n";
	$fileOut .=  "echo \"FINISH RUNNING FILE $cFile OUT OF " . scalar(@infiles) . "\t$file\"\n";
	$fileOut .=  "echo \"" . "*"x20 . "\n\n\n\"\n\n\n";

}

$fileOut .= $actuatorResult;

$fileOut .= $insertResult;

$fileOut .= $opt;

$fileOut .= $indexResult;

$fileOut .= $probeResult;


open  FILE, ">run.sh" or die "COULD NOT CREATE RUN.SH SCRIPT";
print FILE $fileOut;
close FILE;
`chmod +x run.sh`;

print @infiles . " FILES TO BE ANALIZED\n";
print "!"x40 . "\nPLEASE EXECUTE\nreset; time ./run.sh | tee running.log\n" . "!"x40 . "\n";

# print `./probe_uniq.pl $outdir`;


sub checkSetup
{
	my $error;
	if ( ! -d $indir                ) { $error .= "ERROR :: INDIR ".                  $indir                . " NOT FOUND\n" };
	if ( ! -d $currentDir           ) { $error .= "ERROR :: CURRENT DIR ".            $currentDir           . " NOT FOUND\n" };
	if ( ! -d $storageDir           ) { $error .= "ERROR :: STORAGE DIR ".            $storageDir           . " NOT FOUND\n" };
	if ( ! -d $storageDirInput      ) { $error .= "ERROR :: STORAGE INPUT DIR ".      $storageDirInput      . " NOT FOUND\n" };
	if ( ! -d $storageDirDumps      ) { $error .= "ERROR :: STORAGE DUMP DIR ".       $storageDirDumps      . " NOT FOUND\n" };

	if ( ! -f $probeResultScript    ) { $error .= "ERROR :: PROBE RESULT SCRIPT ".    $probeResultScript    . " NOT FOUND\n" };
	if ( ! -f $probeExtractorScript ) { $error .= "ERROR :: PROBE EXTRACTOR SCRIPT ". $probeExtractorScript . " NOT FOUND\n" };
	if ( ! -f $probeActuatorScript  ) { $error .= "ERROR :: PROBE ACTUATOR SCRIPT ".  $probeActuatorScript  . " NOT FOUND\n" };

#	if ( ! -f $storageDirScript     ) { $error .= "ERROR :: STORAGE DIR SCRIPT ".     $storageDirScript     . " NOT FOUND\n" };

	if ( ! -f $sqlDropScript        ) { $error .= "ERROR :: DROP SCRIPT ".            $sqlDropScript        . " NOT FOUND\n" };
	if ( ! -f $sqlFlushScript       ) { $error .= "ERROR :: FLUSH SCRIPT ".           $sqlFlushScript       . " NOT FOUND\n" };
	if ( ! -f $sqlOptScript         ) { $error .= "ERROR :: OPTMIZE SCRIPT ".         $sqlOptScript         . " NOT FOUND\n" };
	if ( ! -f $sqlStartScript       ) { $error .= "ERROR :: START SCRIPT ".           $sqlStartScript       . " NOT FOUND\n" };

	if ( ! -f $indirTaxonomyFile    ) { $error .= "ERROR :: TAXONOMY FILE ".          $indirTaxonomyFile    . " NOT FOUND\n" };

	if ( defined $error )
	{
		die $error;
	}
	else
	{
		my $out;
		$out .= "INDIR                     : ". $indir                . "\n";
		$out .= "CURRENT DIR               : ". $currentDir           . "\n";
		$out .= "STORAGE DIR               : ". $storageDir           . "\n";
		$out .= "STORAGE INPUT DIR         : ". $storageDirInput      . "\n";
		$out .= "STORAGE DUMP  DIR         : ". $storageDirDumps      . "\n";

		$out .= "PROBE RESULT       SCRIPT : ". $probeResultScript    . "\n";
		$out .= "PROBE EXTRACTOR    SCRIPT : ". $probeExtractorScript . "\n";
		$out .= "PROBE ACTUATOR     SCRIPT : ". $probeActuatorScript  . "\n";
		$out .= "PROBE ACTUATOR BASHSCRIPT : ". $probeActuatorBash    . "\n"; #DINAMICALLY GENERATED

		$out .= "PROBE INPUT SCRIPT        : ". $probeInputScript     . "\n";
		$out .= "SQL DROP           SCRIPT : ". $sqlDropScript        . "\n";
		$out .= "SQL FLUSH          SCRIPT : ". $sqlFlushScript       . "\n";
		$out .= "SQL OPTIMIZATION   SCRIPT : ". $sqlOptScript         . "\n";
		$out .= "SQL START          SCRIPT : ". $sqlStartScript       . "\n";
		$out .= "OPTIMIZATION RATE         : ". $optRate              . "\n";
		$out .= "TAXONOMY FILE             : ". $indirTaxonomyFile    . "\n";
		print $out;
	}
}





sub getIndexScript
{
	my $str = <<EOI

echo "ADDING SQL KEYS"
ERRO=\`mysql -u$sqlUser -D$sqlDatabase < $sqlIndexScript 2>&1\`
while [ -n \"\$ERRO\" ]; do
	echo \"\tERROR: \$ERRO :: TRYING AGAIN SQL\"
	ERRO=\`mysql -u$sqlUser -D$sqlDatabase < $sqlIndexScript 2>&1\`

	if [ -n \"\$ERRO\" ]; then
		echo \"\tERROR AGAIN: \$ERRO\"
	else
		echo \"\tSUCCESS ON \$BASENAME\"
		ERRO=\"\"
	fi
done

echo "SQL DONE"




EOI

;

	return $str;
}





sub getInsertAction
{
	my $str = "";
#"echo NOTHING TO DO ON ACTION";

	return $str;
}


sub getInsertActionPos
{
	my $basedir    = $_[0];
	my $listdir    = $_[1];
	my $extension  = $_[2];

	my $str = <<EOI

echo "NOTHING TO DO ON ACTION"
echo ""
echo "MERGING SQL"
rm $listdir/allatonce.sql 2>/dev/null
cat $listdir/*.sql >$listdir/allatonce.sql
echo "ADDING SQL"
ERRO=\`mysql -u$sqlUser -D$sqlDatabase < $listdir/allatonce.sql 2>&1\`
while [ -n \"\$ERRO\" ]; do
	echo \"\tERROR: \$ERRO :: TRYING AGAIN SQL\"
	ERRO=\`mysql -u$sqlUser -D$sqlDatabase < $listdir/allatonce.sql 2>&1\`

	if [ -n \"\$ERRO\" ]; then
		echo \"\tERROR AGAIN: \$ERRO\"
	else
		echo \"\tSUCCESS ON \$BASENAME\"
		ERRO=\"\"
	fi
done


echo "RENAMING SQL"
rename .sql .did $listdir/*.sql


echo "ADDING SQL KEYS"
ERRO=\`mysql -u$sqlUser -D$sqlDatabase < $sqlIndexScript 2>&1\`
while [ -n \"\$ERRO\" ]; do
	echo \"\tERROR: \$ERRO :: TRYING AGAIN SQL\"
	ERRO=\`mysql -u$sqlUser -D$sqlDatabase < $sqlIndexScript 2>&1\`

	if [ -n \"\$ERRO\" ]; then
		echo \"\tERROR AGAIN: \$ERRO\"
	else
		echo \"\tSUCCESS ON \$BASENAME\"
		ERRO=\"\"
	fi
done

echo "SQL DONE"




EOI

;

	return $str;
}





sub getInsertAction2
{
	my $str = <<EOG

	cat << EOI >> \$RUNNUMBER

echo \"\\\$\\\$\" > \$RUNNUMBER.pid
echo \"\$number \$countp/\$SPLIT \$BASENAME\"
ERRO=\\\`mysql -u$sqlUser -D$sqlDatabase < \$BASENAME 2>&1\\\`
while [ -n \"\\\$ERRO\" ]; do
	echo \"\tERROR: \\\$ERRO :: TRYING AGAIN \$BASENAME\"
	ERRO=\\\`mysql -u$sqlUser -D$sqlDatabase < \$BASENAME 2>&1\\\`

	if [ -n \"\\\$ERRO\" ]; then
		echo \"\tERROR AGAIN: \\\$ERRO\"
	else
		echo \"\tSUCCESS ON \$BASENAME\"
		ERRO=\"\"
	fi
done
ERRO=\"\"
mv \$BASENAME \$BASENAME.did
echo \"\tFILE \$BASENAME MOVED\"


EOI

EOG

;

	return $str;
}



sub getActuatorAction
{
	#	$probeActuatorScript \$BASENAME
	#	java -jar /mnt/ssd/probes/mlpaextractor.jar \$BASENAME
	my $str = <<EOG

cat << EOH >> \$RUNNUMBER

	echo \$countp \$number/\$SPLIT \$BASENAME
	$probeActuatorScript ACTUATOR \$BASENAME

EOH

cat << EOI >> \$RUNNUMBER

	echo ""
	echo "###########################################"
	echo "### \$RUNNUMBER \$countp \$number/\$SPLIT \$BASENAME HAS FINISH"
	echo "###########################################"
	echo ""

EOI


EOG
;

	return $str;
}

sub getActuatorActionPos
{
	my $str = "echo NOTHING TO DO ON POS-ACTION";

	return $str;
}



sub mkBashThread
{
	my $basedir    = $_[0];
	my $listdir    = $_[1];
	my $extension  = $_[2];
	my $runname    = $_[3];
	my $outputFile = $_[4];
	my $action     = $_[5];
	my $actionPos  = $_[6];

	my $actionStr    = $action->(    @_[0 .. 4] );
	my $actionPosStr = $actionPos->( @_[0 .. 4] );

	#my $localInsert = $inserts - 1;

	my $string = <<EOF
#reset

#basic directory where to output scripts
BASEDIR="$basedir"

#number of processes to divide into
PROCESSES=$inserts

#list all databases of a given extension ($extension)
DATABASES=( \$(ls -S -r $listdir/*.$extension 2>/dev/null) )
#-S SORT BY SIZE. not a good idea

#prefix of bash scripts dinammically generated
RUNNAME=$runname

#delete all previous scripts
rm -f \$BASEDIR/\$RUNNAME*.sh     2>/dev/null
rm -f \$BASEDIR/\$RUNNAME*.sh.pid 2>/dev/null
rm -f \$BASEDIR/\$RUNNAME.pid     2>/dev/null


count=-1
number=1
total=\${#DATABASES[@]}
SPLIT=`echo "\$total/\$PROCESSES" | bc`
echo \$\$ THERE ARE \$total DATABASES SPLITED IN $inserts PROCESSES CONTAINING \$SPLIT SEQUENCES EACH  > \$RUNNAME.log
echo \$\$ THERE ARE \$total DATABASES SPLITED IN $inserts PROCESSES CONTAINING \$SPLIT SEQUENCES EACH

#generates pid file
echo \$\$ > $runname.pid

#if there's no file, leave
if [ \$SPLIT == 0 ]; then
	echo "NOTHING TO DO. EXITING."
	exit 0
fi






#foreach sequence
for element in \$(seq 0 \$((\${#DATABASES[@]} -1)))
do
	((count++))
	if [ \$count == \$PROCESSES ]; then
		count=0
		((number++))
	fi

	BASENAME=\${DATABASES[\$element]}
	countp=\$((count + 1))

	#generate log
	cat << EOH >> \$RUNNAME.log
		\"\$number \$countp/\$SPLIT \$BASENAME \$\$\"
EOH

RUNNUMBER="\$BASEDIR/\$RUNNAME\$count.sh"




########
######## START OF SPECIFIC ACTION TO BE UNDERTAKEN
########
	$actionStr
########
######## END   OF SPECIFIC ACTION TO BE UNDERTAKEN
########



done


$actionPosStr



#list all bash scripts
RUNS=( \$(ls \$BASEDIR/\$RUNNAME*.sh 2>/dev/null) )

for element in \$(seq 0 \$((\${#RUNS[@]} -1)))
do
	BASENAME=\${RUNS[\$element]}
	echo \$BASENAME

cat << EOO >> \$BASENAME

	echo ""
	echo "###########################################"
	echo "###########################################"
	echo "###########################################"
	echo "########## \$BASENAME HAS FINISH"
	echo "###########################################"
	echo "###########################################"
	echo "###########################################"
	echo ""

EOO

	chmod +x \$BASENAME
	\$BASENAME >> \$RUNNAME.log &
# | tee >> \$RUNNAME.log &
done

WAITS=0
FILES=( \$(ls $listdir/*.$extension 2>/dev/null) )
while [[ \${#FILES[@]} > 0 ]]
do
 ((WAITS++))
 echo \$WAITS STILL RUNNING. \${#FILES[@]} LEFT. PLEASE WAIT
 FILES=( \$(ls $listdir/*.$extension 2>/dev/null) )
 sleep 15
done


EOF
;

	open  SCRIPT, ">$outputFile" or die "COULD NOT CREATE BASH THREAD SCRIPT SCRIPT: $outputFile : $!";
	print SCRIPT $string;
	close SCRIPT;
	`chmod +x $outputFile`;
}











1;
