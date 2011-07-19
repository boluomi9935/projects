QUALITY="/home/saulo/Desktop/rolf/rolf2/wc/hadQualityCheck.pl"
PAIRS="/home/saulo/Desktop/rolf/rolf2/wc/hadFindPairs.pl"
HTML="java -jar /home/saulo/Desktop/rolf/rolf2/wc/xalan-j_2_7_1/xalan.jar"
BLAST="/home/saulo/Desktop/rolf/rolf2/wc/netblast -p blastn -d nr -a 5 -e 1 "

INFOLDER="/home/saulo/Desktop/rolf/rolf2/wc/out"
OUTFOLDER="/home/saulo/Desktop/rolf/rolf2/wc/out/manual"
INTSUFIX=".pass.had"
ENDSUFIX=".probe.pairs.tab"
XMLSUFIX=".probe.pairs.xml"
HMLSUFIX=".probe.pairs.html"
FASTAFWDSUFIX=".probe.pairs.fwd.fasta"
FASTAREVSUFIX=".probe.pairs.rev.fasta"
SLEEPTIME="5m"

echo "QUALITY      : "${QUALITY}
echo "PAIRS        : "${PAIRS}
echo "BLAST        : "${BLAST}
echo "INFOLDER     : "${INFOLDER}
echo "OUTFOLDER    : "${OUTFOLDER}
echo "INTSUFIX     : "${INTSUFIX}
echo "ENDSUFIX     : "${ENDSUFIX}
echo "FASTAFWDSUFIX: "${FASTAFWDSUFIX}
echo "FASTAREVSUFIX: "${FASTAREVSUFIX}

#<outputfile> <shared (0-1)> <species array>
function analysis {
	OFILE=$1
    SHARED=$2
    array_str="$3[*]"
    array=(${!array_str})
    GREPS="| grep -v \";\""
    PAIR=""

    if [ "$SHARED" -eq 1 ]
    then
        GREPS="| grep \";\""
    fi

    element_count=${#array[@]}
    index=0;

    while [ "$index" -lt "$element_count" ]
    do
        #echo "${index} / ${element_count} = "${array[$index]}
        GREPS=${GREPS}" | grep \"${array[${index}]}\""
        ((index++))
    done

    index=0;
    while [ "$index" -lt "$element_count" ]
    do
        #echo "${index} / ${element_count} = "${array[$index]}
        PAIR=${PAIR}" \"${array[${index}]}\""
        ((index++))
    done

    CAT="gunzip -c ${INFOLDER}/*.had.gz"
    #CAT="cat ${INFOLDER}/*.tax.had"
    INT1="${OUTFOLDER}/${OFILE}"
    INT2="${INT1}${INTSUFIX}"
    INTX="${INT2}${XMLSUFIX}"
    INTH="${INT2}${HMLSUFIX}"
    OUTF="${INT2}${FASTAFWDSUFIX}"
    OUTR="${INT2}${FASTAREVSUFIX}"
    OUTFB="${OUTF}.blast"
    OUTRB="${OUTR}.blast"

    FINAL="("
    FINAL=${FINAL}" ${CAT}      ${GREPS} > ${INT1};"   #filter positives
    FINAL=${FINAL}" ${QUALITY}  ${INT1};"              #run quality check
    FINAL=${FINAL}" ${PAIRS}    ${INT2}      ${PAIR};"      #search for suitable pairs
    FINAL=${FINAL}" ${HTML} -IN ${INTX} -OUT ${INTH};"      #search for suitable pairs
    #FINAL=${FINAL}" ${BLAST} -i ${OUTF} -o ${OUTFB} 2>/dev/null;" #run netblast over fwd fasta
    #FINAL=${FINAL}" ${BLAST} -i ${OUTR} -o ${OUTRB} 2>/dev/null;" #run netblast over rev fasta
    FINAL=${FINAL}" ) &"

    ##FINAL=${FINAL}" cat ${INT3} | gawk '{print \$1}' | uniq | gawk '{print \">\"\$1\"\\n\"\$1\"\\n\" }' > ${OUTF};" #convert fwd to fasta
	##FINAL=${FINAL}" cat ${INT3} | gawk '{print \$4}' | uniq | gawk '{print \">\"\$1\"\\n\"\$1\"\\n\" }' > ${OUTR};" #convert rev to fasta
    ##FINAL=${FINAL}" echo rm -f \$(ls -l ${INT1} ${INT2} ${INT3} ${OUTF} ${OUTR} ${OUTFB} ${OUTRB} | awk '\$5 == \"0\" {print \"${OUTFOLDER}/\"\$NF}')" # delete empty files


#	echo "OFILE : "${OFILE}
#    echo "SHARED: "${SHARED}
#    echo "GREPS : "${GREPS}
#    echo "PAIR  : "${PAIR}
#    echo "CAT   : "${CAT}
#    echo "INT1  : "${INT1}
#    echo "INT2  : "${INT2}
#    echo "INTX  : "${INTX}
#    echo "INTH  : "${INTH}
#    echo "OUTF  : "${OUTF}
#    echo "OUTR  : "${OUTR}
#    echo "OUTFB : "${OUTFB}
#    echo "OUTRB : "${OUTRB}
    echo "FINAL : "${FINAL}

    eval $FINAL
}

#crypto
OUTFILE="Cryptococcus_neoformans_var_neoformans_B3501A_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('5207\.0')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Cryptococcus_neoformans_var_neoformans_JEC21_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('5207\.1')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Cryptococcus_neoformans_var_grubii_H99_SCAFFOLD.fasta.tax.had"
SHARE=0
SPECIES=('5207\.2')
analysis $OUTFILE $SHARE SPECIES


sleep ${SLEEPTIME}


OUTFILE="Cryptococcus_gattii_R265_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('552467\.0')
analysis $OUTFILE $SHARE SPECIES

#REDO - 22GB ALONE
#OUTFILE="Cryptococcus_gattii_WM276_GENES.fasta.tax.had"
#SHARE=0
#SPECIES=('552467\.1')
#analysis $OUTFILE $SHARE SPECIES

OUTFILE="Cryptococcus_gattii_spp.fasta.tax.had"
SHARE=1
SPECIES=('552467\.0' '552467\.1')
analysis $OUTFILE $SHARE SPECIES


sleep ${SLEEPTIME}


OUTFILE="Cryptococcus_neoformans_spp.fasta.tax.had"
SHARE=1
SPECIES=('5207\.0' '5207\.1' '5207\.2')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Cryptococcus_neoformans_neoformans_spp.fasta.tax.had"
SHARE=1
SPECIES=('5207\.0' '5207\.1')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Cryptococcus_sp.tax.had"
SHARE=1
SPECIES=('5207\.0' '5207\.1' '5207\.2' '552467\.0' '552467\.1')
analysis $OUTFILE $SHARE SPECIES


sleep ${SLEEPTIME}




##candida
OUTFILE="Candida_albicans_sc5314_assembly_21_1_CONTIGS.fasta.tax.had"
SHARE=0
SPECIES=('5476\.0')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Candida_albicans_wo1_1_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('5476\.1')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Candida_dubliniensis_CD36_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('42374\.0')
analysis $OUTFILE $SHARE SPECIES


sleep ${SLEEPTIME}


OUTFILE="Candida_guilliermondii_1_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('4929\.0')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Candida_lusitaniae_1_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('36911\.0')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Candida_parapsilosis_1_CONTIGS.fasta.tax.had"
SHARE=0
SPECIES=('5480\.0')
analysis $OUTFILE $SHARE SPECIES


sleep ${SLEEPTIME}


OUTFILE="Candida_tropicalis_3_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('5482\.0')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Candida_kruisii_CONTIGS.fasta.tax.had"
SHARE=0
SPECIES=('45561\.0')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Candida_glabrata_CBS138_CHROMOSSOMES.fasta.tax.had"
SHARE=0
SPECIES=('5478\.0')
analysis $OUTFILE $SHARE SPECIES


sleep ${SLEEPTIME}


OUTFILE="Candida_albicans_spp.fasta.tax.had"
SHARE=1
SPECIES=('5476\.0' '5476\.1')
analysis $OUTFILE $SHARE SPECIES

OUTFILE="Candida_sp.tax.had"
SHARE=1
SPECIES=('5476\.0' '5476\.1' '42374\.0' '4929\.0' '36911\.0' '5480\.0' '5482\.0' '45561\.0')
analysis $OUTFILE $SHARE SPECIES



























#crypto
#OUTFILE="Cryptococcus_neoformans_var_neoformans_B3501A_CHROMOSSOMES.fasta.tax.had"
#(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5207\.0"   > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE}; ${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Cryptococcus_neoformans_var_neoformans_JEC21_CHROMOSSOMES.fasta.tax.had"
#(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5207\.1"   > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Cryptococcus_neoformans_var_grubii_H99_SCAFFOLD.fasta.tax.had"
#(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5207\.2"   > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Cryptococcus_gattii_R265_CHROMOSSOMES.fasta.tax.had"
#(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "552467\.0" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Cryptococcus_gattii_WM276_GENES.fasta.tax.had"
#(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "552467\.1" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Cryptococcus_gattii_spp.fasta.tax.had"
#(cat ${INFOLDER}/*.tax.had | grep ";"    | grep "552467\.1" | grep "552467\.0" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Cryptococcus_neoformans_spp.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep ";"    | grep "5207\.0"   | grep "5207\.1" | grep "5207\.2" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta)

#OUTFILE="Cryptococcus_sp.tax.had"
#(cat ${INFOLDER}/*.tax.had | grep ";"    | grep "5207\.0"   | grep "5207\.1" | grep "5207\.2" | grep "552467\.0" | grep "552467\.1" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &


#candida
#OUTFILE="Candida_albicans_sc5314_assembly_21_1_CONTIGS.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5476\.0"  > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_albicans_wo1_1_CHROMOSSOMES.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5476\.1"  > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_Candida_dubliniensis_CD36_CHROMOSSOMES.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "42374\.0" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_guilliermondii_1_CHROMOSSOMES.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "4929\.0"  > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_lusitaniae_1_CHROMOSSOMES.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "36911\.0" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_parapsilosis_1_CONTIGS.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5480\.0"  > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_tropicalis_3_CHROMOSSOMES.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5482\.0"  > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_kruisii_CONTIGS.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "45561\.0" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_glabrata_CBS138_CHROMOSSOMES.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep -v ";" | grep "5478\.0"  > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_albicans_spp.fasta.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep ";"    | grep "5476\.0" | grep "5476\.1" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &

#OUTFILE="Candida_sp.tax.had"
#	(cat ${INFOLDER}/*.tax.had | grep ";"    | grep "5476\.0" | grep "5476\.1" | grep "42374\.0" | grep "4929\.0" | grep "36911\.0" | grep "5480\.0" | grep "5482\.0" | grep "45561\.0" > ${OUTFOLDER}/${OUTFILE};
#	${QUALITY} ${OUTFOLDER}/${OUTFILE};
#	${PAIRS} ${OUTFOLDER}/${OUTFILE}${INTSUFIX};
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $1}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.fwd.fasta;
#	cat ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX} | gawk '{print $4}' | uniq | gawk '{print ">"$1"\n"$1"\n" }' > ${OUTFOLDER}/${OUTFILE}${INTSUFIX}${ENDSUFIX}.rev.fasta) &
