#!/bin/bash

BASES=`cat input/*.fasta | grep -v ">" | wc -c`
SPEED=2500

BASESK=$(($BASES/1000))
BASESM=$(($BASESK/1000))
TIMES=$(($BASES/$SPEED))
TIMEM=$(($TIMES/60))
TIMEH=$(($TIMEM/60))
TIMED=$(($TIMEH/24))
TIMEMS=`echo $TIMES/60| bc -l`
TIMEHS=`echo $TIMEM/60| bc -l`
TIMEDS=`echo $TIMEH/24| bc -l`
echo $SPEED Bb/s
echo $BASES Bb
echo $BASESK Kb
echo $BASESM Mb
echo $TIMES seconds
echo $TIMEMS minuts
echo $TIMEHS hours
echo $TIMEDS days

