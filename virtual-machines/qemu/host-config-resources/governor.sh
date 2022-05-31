#!/bin/bash
set -o nounset
set -o pipefail

################################################
# Script for interracting with the linux cpu governor
# source: https://www.kernel.org/doc/Documentation/cpu-freq/governors.txt
#
# Governor types:
# 'performance' - value of scaling_max_freq
# 'powersave' - value of scaling_min_freq
# 
# Test metal host has 8 cores / 16 threads
# https://ark.intel.com/content/www/us/en/ark/products/212279/intel-core-i711700-processor-16m-cache-up-to-4-90-ghz.html

# get the power status of all cores
core_status(){
VCORES=$(ls -l /sys/devices/system/cpu/ | grep -E 'cpu[0-9]*$' |grep -c cpu)
let "VCORES=VCORES-1"

for ((i=0;i<=$VCORES;i++)); do
    FILE=$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor")
    echo "$i: $FILE"
done
}

# set the power status of an individual core
# set_core_state <cpu_core_number> <performance/powersave>
set_core_state(){
    FILE="/sys/devices/system/cpu/cpu$1/cpufreq/scaling_governor"
    echo "$2" > $FILE
    core_status |grep -w "$1"
}

# set all cores to a specified governer
# set_all_cores <performance/powersave>
set_all_cores(){
VCORES=$(ls -l /sys/devices/system/cpu/ | grep -E 'cpu[0-9]*$' |grep -c cpu)
let "VCORES=VCORES-1"

for ((i=0;i<=$VCORES;i++)); do
    FILE="/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
    echo "$1" > $FILE
done

core_status
}

"$@"