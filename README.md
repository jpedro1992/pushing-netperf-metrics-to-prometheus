# pushing-netperf-metrics-to-prometheus

Repository for the netperf component used by the Diktyo framework for the Kubernetes platform.

The goal is to perform netperf measurements between cluster nodes in Kubernetes and 
store the values as metrics in a [Configmap](https://kubernetes.io/docs/concepts/configuration/configmap/) to make scheduling decisions based on latency.

## Netperf Component

The netperf component is based on the k8s-netperf open-sourced [here](https://github.com/leannetworking/k8s-netperf)

First, you should run `kubectl apply -f k8s-netperf.yaml` to deploy the netperf pods as daemon sets. 
After deployment, the number of pods in the cluster depends on the number of nodes in your cluster: 

```shell
kubectl get pods -n default

NAME                           READY   STATUS    RESTARTS   AGE
netperf-host-2hngp             1/1     Running   0          15s
netperf-host-47jj6             1/1     Running   0          15s
netperf-host-4wbfq             1/1     Running   0          15s
netperf-host-7ltcw             1/1     Running   0          15s
netperf-host-9stmq             1/1     Running   0          15s
netperf-host-dfvmq             1/1     Running   0          15s
netperf-host-ftssm             1/1     Running   0          15s
netperf-host-hdzwq             1/1     Running   0          15s
netperf-host-hlvsh             1/1     Running   0          15s
netperf-host-jznvh             1/1     Running   0          15s
netperf-host-knnts             1/1     Running   0          15s
netperf-host-qfhms             1/1     Running   0          15s
netperf-host-qqhhg             1/1     Running   0          15s
netperf-host-srjz6             1/1     Running   0          15s
netperf-host-xj8lm             1/1     Running   0          16s
netperf-pod-2pk86              1/1     Running   0          16s
netperf-pod-77c9846498-gpfbv   1/1     Running   0          16s
netperf-pod-77c9846498-jrv7w   1/1     Running   0          16s
netperf-pod-8jhrg              1/1     Running   0          16s
netperf-pod-chlwx              1/1     Running   0          16s
netperf-pod-fhz9m              1/1     Running   0          16s
netperf-pod-gmhp2              1/1     Running   0          16s
netperf-pod-k6xfb              1/1     Running   0          16s
netperf-pod-mz6xh              1/1     Running   0          16s
netperf-pod-p6knm              1/1     Running   0          16s
netperf-pod-s29p4              1/1     Running   0          16s
netperf-pod-sd7k5              1/1     Running   0          16s
netperf-pod-tg5gw              1/1     Running   0          16s
netperf-pod-vbqj6              1/1     Running   0          16s
netperf-pod-w955l              1/1     Running   0          16s
netperf-pod-wt9cg              1/1     Running   0          16s
netperf-pod-z9r86              1/1     Running   0          16s
```

Then, you run our script `./runTestConfigmap.sh` to:

- run the netperf measurements through the netperf pods. 
- create the configmap based on the `netperfMetrics.txt`.

The k8s-netperf perl script has been modified to run netperf tests between nodes and save the results in a .txt file. 
Two options exist: 

1) `runNetperfConfigmap.pl`: It runs a test per node to another random node.  
2) `runNetperfConfigmapV2.pl`: It runs a test for all nodes to every possible destination.

The first option is faster but not all data will be available. at a given moment:

The second option takes longer but all data is available in the configmap.

The goal is to store latency metrics in a configmap, especially different latency percentiles (i.e., 50th, 90th and 99th percentile latency in microseconds).



## Examples 

Example of a netperfMetrics.txt file:

```txt
netperf.p90.latency.milliseconds.origin.n1.destination.n2=60
netperf.p90.latency.milliseconds.origin.n1.destination.n3=109
netperf.p90.latency.milliseconds.origin.n1.destination.n4=30
netperf.p90.latency.milliseconds.origin.n2.destination.n1=60
netperf.p90.latency.milliseconds.origin.n2.destination.n2=109
netperf.p90.latency.milliseconds.origin.n2.destination.n3=10
netperf.p90.latency.milliseconds.origin.n3.destination.n1=60
netperf.p90.latency.milliseconds.origin.n3.destination.n2=70
netperf.p90.latency.milliseconds.origin.n3.destination.n4=60
netperf.p90.latency.milliseconds.origin.n4.destination.n1=60
netperf.p90.latency.milliseconds.origin.n4.destination.n2=40
netperf.p90.latency.milliseconds.origin.n4.destination.n3=60
```

## Contact

For questions or support, please use GitHub's issue system.