#!/bin/bash

# find the number of real cores/cpus in a box - ignore hyperthreading 'logical' CPUs

if [ ! -r /proc/cpuinfo ]; then
        echo 'Is this Linux? Cannot find or read /proc/cpuinfo'
        exit 1
fi

# check if the physical id and core id fields are there. if not, just use
#       raw processor count as the number
num_cores=`grep 'physical id' /proc/cpuinfo | sort -u | wc -l`

if [ $num_cores -eq 0 ]; then
        # this box is either an old SMP or single-CPU box, so count the # of processors
        num_cores=`grep '^processor' /proc/cpuinfo | sort -u | wc -l`
else
        # have to factor in physical id (physical CPU) and core id (multi-core)
        # for each 'processor' in /proc/cpuinfo
        #       concatenate  physical_id and core_id  then find the unique list of these
        #       to get the # of cores/cpus
        list=(`grep -iE '(physical|core).*id' /proc/cpuinfo | cut -d: -f2 | tr -d ' '`)
        index=0
        for ent in ${list[@]}; do
                new_index=$(($index/2))
                tmp=${new_list[$new_index]}
                if [ -z '$tmp' ]; then
                        new_list[$new_index]='$ent'
                else
                        new_list[$new_index]='$tmp,$ent'
                fi
                index=$(($index+1))
        done

        num_cores=`echo ${new_list[*]} | tr ' ' '\n' | sort -u | wc -l`

fi

echo $num_cores

