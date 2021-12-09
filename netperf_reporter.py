#!/usr/bin/env python3

# This script is based on the netperf-reporter from Cilium.
# Link: https://github.com/cilium/cilium/blob/master/contrib/scripts/netperf_reporter.py
# It reads a .csv file and pushes the results to the Prometheus PushGateway to be consumed by Prometheus.

# Prometheus variables to run the script:
# - PROMETHEUS_URL: pushGateway URL, example: https://localhost:9091/metrics/job/"some_job"/instance/"some_instance"
# - PROMETHEUS_USR: username if needed
# - PROMETHEUS_PSW: password if needed

import argparse
import logging
import requests
import sys
import pandas as pd

logging.basicConfig(filename='netperf_reporter.log', filemode='w', level=logging.DEBUG)
logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')

parser = argparse.ArgumentParser(description='Run netperf reporter...')
parser.add_argument('--file', default='results.csv', type=str, help='The .csv file with netperf measurements.')

args = parser.parse_args()

# Prometheus Configuration for the PushGateway
PROMETHEUS_CONFIG = dict(
    URL="http://localhost:9091/metrics/job/netperf/instance/networkAware",
    USR="",
    PSW="")

# Add your metric keys here
keys = ["netperf_p50_latency_microseconds", "netperf_p90_latency_microseconds", "netperf_p99_latency_microseconds"]


# read the csv and and return an string with an array with
# key=>value data to push to any metrics system.
def read_data(filename):
    result = []
    df = pd.read_csv(filename)
    logging.info("Reading csv file... Dataframe: ")
    logging.info(df)

    for ind, row in df.iterrows():
        for k in keys:
            result.append(
                ('{0}{{origin="{1}", destination="{2}"}}'.format(k, row['origin'], row['destination']), row[k]))

    logging.info("Retrieved '{0}' metrics".format(len(result)))
    return result


# it receives a tuple with key value storage and push the info to
# prometheus PushGateway server
def push_to_prometheus(data):
    result = ""

    # Add Gauge type to metrics
    for k in keys:
        result += "{0}\n".format("# HELP " + k + " netperf measurement pushed to the Prometheus Pushgateway.")
        result += "{0}\n".format("# TYPE " + k + " gauge")

    # logging.info("TYPE of metrics: ")
    # logging.info(result)

    for metric, value in data:
        metric_key = metric.replace(".", "_")
        result += "{0} {1}\n".format(metric_key, value)
        logging.info("Metric {0} has the value {1}".format(metric_key, value))

    req = requests.post(
        PROMETHEUS_CONFIG.get("URL"),
        data=result,
        auth=(PROMETHEUS_CONFIG.get("USR"), PROMETHEUS_CONFIG.get("PSW"))
    )

    if req.status_code == 200:
        logging.info("Data pushed correctly to prometheus")
        return True

    logging.error(
        "Cannot push data to prometheus:"
        "err='{0.text}' status_code={0.status_code}".format(req))
    return False


def main():
    # Import and initialize Environment
    logging.info(args)

    csv = args.file

    if csv == "":
        logging.error("CSV file to retrieved data is not defined.")
        sys.exit(1)
    # Try to read data
    try:
        data = read_data(csv)
    except IOError:
        logging.error("{0} cannot open file! Exit... ".format(csv))
        sys.exit(1)

    if len(data) == 0:
        logging.error("No data was retrieved...")
        sys.exit(1)

    # Send data to PushGateway
    push_to_prometheus(data)


if __name__ == "__main__":
    main()
