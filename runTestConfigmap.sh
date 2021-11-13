#!/bin/bash
# Purpose: Measure latency between nodes in k8s cluster
#          and save measurements in a configmap
# Author: Jose Santos
# ---------------------------------------------------------------------------

# Set time for sleep, default 60 seconds
SLEEP=60

# Number of Runs
NUM=1

# loop
for (( i=1; i<=${NUM}; i++ ))
do  	
	# show menu
	clear
	echo "---------------------------------"
	echo "[Network Aware Scheduling] Netperf component"
	echo "---------------------------------"
	#echo "Sleep set to $SLEEP seconds"

 	echo "Run Perl script to measure the latency in the cluster..."
	perl runNetperfConfigmapV2.pl 2>>logNetperf.txt
	
	echo "Create configmap with results"
	kubectl create configmap netperf-metrics --from-file="netperfMetrics.txt" --dry-run=client

  #echo "Sleep for $SLEEP seconds ... "
	#sleep ${SLEEP}
done
