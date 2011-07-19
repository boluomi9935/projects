#reset

#basic directory where to output scripts
BASEDIR="/mnt/ssd/probes"

#number of processes to divide into
PROCESSES=3

#list all databases of a given extension (sql)
DATABASES=( $(ls -S -r /mnt/ssd/probes/input/*.sql 2>/dev/null) )
#-S SORT BY SIZE. not a good idea

#prefix of bash scripts dinammically generated
RUNNAME=run

#delete all previous scripts
rm -f $BASEDIR/$RUNNAME*.sh     2>/dev/null
rm -f $BASEDIR/$RUNNAME*.sh.pid 2>/dev/null
rm -f $BASEDIR/$RUNNAME.pid     2>/dev/null


count=-1
number=1
total=${#DATABASES[@]}
SPLIT=`echo "$total/$PROCESSES" | bc`
echo $$ THERE ARE $total DATABASES SPLITED IN 3 PROCESSES CONTAINING $SPLIT SEQUENCES EACH  > $RUNNAME.log
echo $$ THERE ARE $total DATABASES SPLITED IN 3 PROCESSES CONTAINING $SPLIT SEQUENCES EACH

#generates pid file
echo $$ > run.pid

#if there's no file, leave
if [ $SPLIT == 0 ]; then
	echo "NOTHING TO DO. EXITING."
	exit 0
fi






#foreach sequence
for element in $(seq 0 $((${#DATABASES[@]} -1)))
do
	((count++))
	if [ $count == $PROCESSES ]; then
		count=0
		((number++))
	fi

	BASENAME=${DATABASES[$element]}
	countp=$((count + 1))

	#generate log
	cat << EOH >> $RUNNAME.log
		"$number $countp/$SPLIT $BASENAME $$"
EOH

RUNNUMBER="$BASEDIR/$RUNNAME$count.sh"




########
######## START OF SPECIFIC ACTION TO BE UNDERTAKEN
########
	
########
######## END   OF SPECIFIC ACTION TO BE UNDERTAKEN
########



done



echo "NOTHING TO DO ON ACTION"
echo ""
echo "MERGING SQL"
rm /mnt/ssd/probes/input/allatonce.sql 2>/dev/null
cat /mnt/ssd/probes/input/*.sql >/mnt/ssd/probes/input/allatonce.sql
echo "ADDING SQL"
ERRO=`mysql -uprobe -Dprobe < /mnt/ssd/probes/input/allatonce.sql 2>&1`
while [ -n "$ERRO" ]; do
	echo "	ERROR: $ERRO :: TRYING AGAIN SQL"
	ERRO=`mysql -uprobe -Dprobe < /mnt/ssd/probes/input/allatonce.sql 2>&1`

	if [ -n "$ERRO" ]; then
		echo "	ERROR AGAIN: $ERRO"
	else
		echo "	SUCCESS ON $BASENAME"
		ERRO=""
	fi
done


echo "RENAMING SQL"
rename .sql .did /mnt/ssd/probes/input/*.sql


echo "ADDING SQL KEYS"
ERRO=`mysql -uprobe -Dprobe < /home/saulo/Desktop/rolf/sql/probe_09_index.sql 2>&1`
while [ -n "$ERRO" ]; do
	echo "	ERROR: $ERRO :: TRYING AGAIN SQL"
	ERRO=`mysql -uprobe -Dprobe < /home/saulo/Desktop/rolf/sql/probe_09_index.sql 2>&1`

	if [ -n "$ERRO" ]; then
		echo "	ERROR AGAIN: $ERRO"
	else
		echo "	SUCCESS ON $BASENAME"
		ERRO=""
	fi
done

echo "SQL DONE"








#list all bash scripts
RUNS=( $(ls $BASEDIR/$RUNNAME*.sh 2>/dev/null) )

for element in $(seq 0 $((${#RUNS[@]} -1)))
do
	BASENAME=${RUNS[$element]}
	echo $BASENAME

cat << EOO >> $BASENAME

	echo ""
	echo "###########################################"
	echo "###########################################"
	echo "###########################################"
	echo "########## $BASENAME HAS FINISH"
	echo "###########################################"
	echo "###########################################"
	echo "###########################################"
	echo ""

EOO

	chmod +x $BASENAME
	$BASENAME >> $RUNNAME.log &
# | tee >> $RUNNAME.log & 
done

WAITS=0
FILES=( $(ls /mnt/ssd/probes/input/*.sql 2>/dev/null) )
while [[ ${#FILES[@]} > 0 ]]
do
 ((WAITS++))
 echo $WAITS STILL RUNNING. ${#FILES[@]} LEFT. PLEASE WAIT
 FILES=( $(ls /mnt/ssd/probes/input/*.sql 2>/dev/null) )
 sleep 15
done


