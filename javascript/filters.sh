INFILTER=$1
EXE=xsltproc
INPUT=output.xml
OUTPUT=$INPUT
FILTERDIR=filters
OUTDIR=filtered

if [ -z $INFILTER ]; then
    FILTERS=( important_full ) 
    #FILTERS=( ${FILTERS[@]} anno )
    #FILTERS=( ${FILTERS[@]} anno_full )
    #
    #FILTERS=( ${FILTERS[@]} class )
    #FILTERS=( ${FILTERS[@]} class_full )
    #FILTERS=( ${FILTERS[@]} class_shared class_splice class_unique )
    #FILTERS=( ${FILTERS[@]} class_shared_full class_splice_full class_unique_full )
    #
    #FILTERS=( ${FILTERS[@]} data  )
    #FILTERS=( ${FILTERS[@]} data_full  )
    #FILTERS=( ${FILTERS[@]} data_FPKM1 data_FPKM2 data_FPKM12 data_FPKM1n2 data_FPKM2n1 )
    #FILTERS=( ${FILTERS[@]} data_FPKM1_full data_FPKM2_full data_FPKM12_full data_FPKM1n2_full data_FPKM2n1_full )
    #
    #FILTERS=( ${FILTERS[@]} span  )
    #FILTERS=( ${FILTERS[@]} span_full  )
    #FILTERS=( ${FILTERS[@]} span_hash )
    #FILTERS=( ${FILTERS[@]} span_hash_full )
    #FILTERS=( ${FILTERS[@]} span_hash_diffge3 span_hash_diffge30 span_hash_diffge300 span_hash_diffge3000 )
    #FILTERS=( ${FILTERS[@]} span_hash_diffge3_full span_hash_diffge30_full span_hash_diffge300_full span_hash_diffge3000_full )
    #FILTERS=( ${FILTERS[@]} span_string )
    #FILTERS=( ${FILTERS[@]} span_string_full )
else
    FILTERS=( $INFILTER )
fi



echo "INPUT $INPUT"
OUTPUT=${OUTPUT%.xml}
echo "OUTPUT $OUTPUT"

if [ ! -f $INPUT ]; then
	echo "INPUT FILE $INPUT WAS NOT FOUND"
	exit 1;
fi

LINESO=`wc -l $INPUT | gawk '{print \$1}'`
CHARSO=`wc -c $INPUT | gawk '{print \$1}'`
echo -e "INPUT LINES: $LINESO"
echo -e "INPUT CHARS: $CHARSO"

for filter in "${FILTERS[@]}"
do
  echo -e "\tRUNNING FILTER $filter"
  
  #XLST="$FILTERDIR/$OUTPUT""_filter_$filter.xlst"
  XLST="$FILTERDIR/$OUTPUT""_filter.xlst"
  OUTFILE="$OUTDIR/$OUTPUT""_out_$filter.xml"
  
  if [ -f "$XLST" ]; then
  	#CMD="$EXE -o $OUTFILE $XLST $INPUT"
        CMD="cat $XLST | ./lazarus $filter | $EXE -o $OUTFILE - $INPUT"
  	echo -e "\t\tCMD  : $CMD"
	eval $CMD
        LINES=`wc -l $OUTFILE | gawk '{print \$1}'`
        CHARS=`wc -c $OUTFILE | gawk '{print \$1}'`
        PERCL=$( echo "scale=2; ($LINES * 100 / $LINESO)" | bc)
        PERCC=$( echo "scale=2; ($CHARS * 100 / $CHARSO)" | bc)
        echo -e "\t\tLINES: $LINES ($PERCL%)"
        echo -e "\t\tLINES: $LINES ($PERCC%)"
  else
	echo -e "\t\tFILE $XLST FOR FILTER $filter WAS NOT FOUND. SKIPPING"
  fi
done
