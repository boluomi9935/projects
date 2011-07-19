DATABASES=( $(ls input/*.sql) )

#DATABASES=(${DATABASES[@]#original/})
#DATABASES=(${DATABASES[@]%.fasta})
rm run*

count=-1
number=1
total=${#DATABASES[@]}
SPLIT=`echo "$total/14" | bc`
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
   echo "echo $number $countp/$SPLIT $BASENAME" >> run$number.sh
   echo "mysql -uprobe -Dprobe < $BASENAME" >> run$number.sh
done


RUNS=( $(ls run*.sh) )

for element in $(seq 0 $((${#RUNS[@]} -1)))
 do
 BASENAME=${RUNS[$element]}
# NEWNAME=$BASENAME.did
   echo $BASENAME
   chmod +x $BASENAME
   ./$BASENAME &
   PID=`ps -ef | grep -i $BASENAME | awk {'print $2'} | head -1`
   echo $PID

#	mysql -uprobe -Dprobe < $BASENAME &
#	mv $BASENAME $NEWNAME
done

