BASEDIR="/mnt/ssd/probes"
DATABASES=( $(ls $BASEDIR/input/*.sql.did) )

DATABASES=(${DATABASES[@]#original/})
DATABASES=(${DATABASES[@]%.did})

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

countp=$count
((countp++))
   echo $BASENAME
  mv $BASENAME.did $BASENAME
done

