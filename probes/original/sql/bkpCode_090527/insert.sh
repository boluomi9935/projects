reset
BASEDIR="/mnt/ssd/probes"
DATABASES=( $(ls $BASEDIR/input/*.sql) )

#DATABASES=(${DATABASES[@]#original/})
#DATABASES=(${DATABASES[@]%.fasta})
rm $BASEDIR/run*.sh 2>/dev/null

count=-1
number=1
total=${#DATABASES[@]}
SPLIT=`echo "$total/10" | bc`
echo THERE ARE $total DATABASES SPLITED IN $SPLIT

for element in $(seq 0 $((${#DATABASES[@]} -1)))
 do
((count++))
if [ $count == $SPLIT ]; then
count=0
((number++))
fi

 BASENAME=${DATABASES[$element]}
# NEWNAME=$BASENAME.did
countp=$count
((countp++))
   echo $BASENAME
   echo "echo $number $countp/$SPLIT $BASENAME" >> $BASEDIR/run$number.sh
   echo "ERRO=\`mysql -uprobe -Dprobe < $BASENAME 2>&1\`" >> $BASEDIR/run$number.sh
   echo "while [ -n \"\$ERRO\" ]; do" >> $BASEDIR/run$number.sh
   echo "  echo \"error: \$ERRO :: TRYING AGAIN $BASENAME\"" >> $BASEDIR/run$number.sh
   echo "  ERRO=\`mysql -uprobe -Dprobe < $BASENAME 2>&1\`" >> $BASEDIR/run$number.sh
   echo "" >> $BASEDIR/run$number.sh
   echo "  if [ -n \"\$ERRO\" ]; then" >> $BASEDIR/run$number.sh
   echo "    echo \"ERROR AGAIN: \$ERRO\"" >> $BASEDIR/run$number.sh
   echo "  else" >> $BASEDIR/run$number.sh
   echo "    echo \"SUCCESS ON $BASENAME\"" >> $BASEDIR/run$number.sh
   echo "  fi" >> $BASEDIR/run$number.sh
   echo "done" >> $BASEDIR/run$number.sh
   echo "ERRO=\"\"" >> $BASEDIR/run$number.sh
   echo "mv $BASENAME $BASENAME.did" >> $BASEDIR/run$number.sh
   echo "" >> $BASEDIR/run$number.sh
   echo "" >> $BASEDIR/run$number.sh
done



RUNS=( $(ls $BASEDIR/run*.sh) )

for element in $(seq 0 $((${#RUNS[@]} -1)))
 do
 BASENAME=${RUNS[$element]}
# NEWNAME=$BASENAME.did
   echo $BASENAME
   chmod +x $BASENAME
   $BASENAME &
#   PID=`ps -ef | grep -i $BASENAME | awk {'print $2'} | head -1`
#   echo $PID

#	mysql -uprobe -Dprobe < $BASENAME &
#	mv $BASENAME $NEWNAME
done

echo THERE ARE $total DATABASES SPLITED IN $SPLIT CONCURENT INSERTS

#for element in $(seq 0 $((${#DATABASES[@]} -1)))
# do

#   BASENAME=${DATABASES[$element]}
#   echo "DELETING $BASENAME"
#   rm $BASENAME.did
#done

#rm $BASEDIR/run*.sh

