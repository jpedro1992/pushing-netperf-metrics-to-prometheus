#!/bin/bash
# Purpose: Measure latency between nodes in k8s cluster
#          and send measurements to Prometheus PushGateway
# Author: Jose Santos
# ---------------------------------------------------------------------------

# Set time for sleep, default 60 seconds
SLEEP=60

# Infinite loop with sleep
while true;do
	# show menu
	clear
	echo "---------------------------------"
	echo "[Network Aware Scheduling] Netperf component"
	echo "---------------------------------"
	echo "Sleep set to $SLEEP seconds"

  echo "Run Perl script to measure the latency in the cluster..."
	perl runNetperf.pl 2>>logNetperf.txt # Or run runNetperfV2.pl ...

	echo "Push Data to Prometheus PushGateway..."
	python3 netperf_reporter.py --file results.csv

	echo "Sleep for $SLEEP seconds ... "
	sleep ${SLEEP}
done
