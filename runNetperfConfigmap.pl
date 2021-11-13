#!/usr/bin/perl -w

###################################################
### This script runs several kubectl commands   ###
### in order to measure the network performance ###
### beetween K8s nodes, pods and services       ###
### in various scenarios.                       ###
###                                             ###
### Requires JSON::Parse, so install it by:     ###
### sudo perl -MCPAN -e 'install JSON::Parse'   ###
###                                             ###
### If make was not OK (e.g. on cloud image),   ###
### than you also need to install make by       ### 
### sudo apt install build-essentials           ###
###                                             ###
### Written by Megyo on 15. May 2018            ###
### Modified by Jose Santos 14 Oct 2021         ###
###################################################

use strict;
use JSON::Parse ':all';
use Text::CSV;
use strict;
use warnings;

# Open the CSV file
#my $csv = Text::CSV->new({ binary => 1, auto_diag => 2, eol => "\n"});

my $filename = 'netperfMetrics.txt';

open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";

# For csv
#$csv->column_names('origin', 'destination', 'netperf_p50_latency_microseconds','netperf_p90_latency_microseconds','netperf_p99_latency_microseconds');
#open my $fh, ">", "results.csv" or die "Failed to open file: $!";

# print csv header
#$csv->print ($fh,['origin','destination','netperf_p50_latency_microseconds','netperf_p90_latency_microseconds','netperf_p99_latency_microseconds']);

#maximum number of measurements in different types
my $numberOfLocalhostMeasurements = 20;
my $numberOfInterNodeMeasurements = 20;
my $iperfTime = 2;

my $netperfRequestPacketSize = 32;
my $netperfResponsePacketSize = 1024;

#hash to store every data on Nodes
my %nodes = ();

#hash to store every data on NetPerf Pods
my %pods = ();

#hash to store every data on Netperf Service
my %services = ();

#simple IP address regular expression
my $IPregexp = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

#reading ARGV for --nobaseline flag
my $nobaseline = 0;
if ((defined($ARGV[0])) and ($ARGV[0] =~ /--nobaseline/)) {
	$nobaseline = 1;
}
print STDERR "No Baseline flag is: $nobaseline\n";

#reading Node, POD and Service information from Kubernetes
&getKubernetesInfo();

#run Iperf between PODs located on the same host
my %randHash = randomPodPairsOnSameNode($numberOfLocalhostMeasurements);

#if only have one node, than exit
exit if (scalar(keys %nodes) < 2);

my @randArray = randomKeysFromHash($numberOfLocalhostMeasurements,%pods);

#run Iperf between Nodes to see maximum internode capacity
my %randNodePairs = randomNodePairs($numberOfInterNodeMeasurements);

foreach my $node (keys %randNodePairs) {
	last if ($nobaseline);
	my $podName = $nodes{$node}->{'HostNetPerf'};
	my $targetIP = $nodes{$randNodePairs{$node}}->{'IPaddress'};

	my $netperfRR = &runNetperf($podName, $targetIP, $iperfTime, 'TCP_RR', 'P50_LATENCY, P90_LATENCY,P99_LATENCY,THROUGHPUT,THROUGHPUT_UNITS');
	print "InterNode NetPerf TCP_RR test between Node $node and Node $randNodePairs{$node} (latency 50, 90 and 99 percentiles in us and DB like transaction rate): $netperfRR\n";
	
	my ($sc1, $sc2, $sc3, $sc4) = split(',', $netperfRR, 4);
	
	# displaying string after splitting
	# print "$sc1\n$sc2\n$sc3\n$sc4";
	
	# print results to csv
	#$csv->print ($fh, [$node, $randNodePairs{$node}, $sc1, $sc2, $sc3]);
	 
	#print $fh "netperf_p50_latency_microseconds.origin.$node.destination.$randNodePairs{$node}=$sc1\n";
	print $fh "netperf_p90_latency_microseconds.origin.$node.destination.$randNodePairs{$node}=$sc2\n";
	#print $fh "netperf_p99_latency_microseconds.origin.$node.destination.$randNodePairs{$node}=$sc3\n";
	
	#$csv->eol ("\r\n");	
}

close $fh;

sub runIperf {
	my ($pod, $serverIP, $time) = @_;
    print STDERR "running command: kubectl exec -it $pod -- iperf -c $serverIP -i 1 -t $time \n";
	open(IPERF, "kubectl exec -it $pod -- iperf -c $serverIP -i 1 -t $time | ");
	my $lastLine = '';
	while (<IPERF>) {
		print STDERR $_;
		$lastLine = $_;
	}
	close(IPERF);
	chomp($lastLine);
	$lastLine =~ s/.*?(\d+\.\d+ .bits\/sec).*/$1/;
	return $lastLine;
}

sub runNetperf {
	my ($pod, $serverIP, $time, $type, $format) = @_;
	my $lastLine = '';
    print STDERR "running command: kubectl exec -it $pod -- netperf -H $serverIP -l $time -P 1 -t $type -- -r $netperfRequestPacketSize,$netperfResponsePacketSize -o $format \n";
	open(NETPERF, "kubectl exec -it $pod -- netperf -H $serverIP -l $time -P 1 -t $type -- -r $netperfRequestPacketSize,$netperfResponsePacketSize -o $format | ");
	while (<NETPERF>) {
		print STDERR $_;
		$lastLine = $_;
	}
	chomp($lastLine);
	close(NETPERF);
	return $lastLine;
}

sub runFortio {
	my ($pod, $serverIP, $time, $flags) = @_;
	my $lastLine = '';
	my $outputstring = '';
	my $port = '';
	$port = ':8080' unless ($flags =~ /grpc/);
    print STDERR "running command: kubectl exec -it $pod -- fortio load $flags -t ${time}s $serverIP$port \n";
	open(FORTIO, "kubectl exec -it $pod -- fortio load $flags -t ${time}s $serverIP$port | ");
	while (my $line = <FORTIO>) {
		print STDERR $line;
		$line =~ s/\n|\r//g;
		$line =~ s/[^0-9a-zA-z %.,]//g;
		$line =~ s/\t/ /g;
		if ($line =~ /target 50% (.*)/) {
			$outputstring .= $1 . ', ';
		}
		elsif ($line =~ /target 90% (.*)/) {
			$outputstring .= $1 . ', ';
		}
		elsif ($line =~ /target 99% (.*)/) {
			$outputstring .= $1 . ', ';
		}
		$lastLine = $line;
	}
	$lastLine =~ s/^.*,//;
	$outputstring .= $lastLine;
	close(FORTIO);
	return $outputstring;
}

sub randomKeysFromHash {
    my $number = shift;
    my %hash = @_; 
    my @randomList = ();
	
    while (($number > 0) and (scalar(keys %hash) > 0)) {
		my $randKey = (keys %hash)[rand keys %hash];
		push @randomList, $randKey;
		delete $hash{$randKey};
		$number--;
	}
	
    return @randomList;
}

sub randomPodPairsOnSameNode {
    my $number = shift;
    my %hash = (); 
    
    foreach my $node (keys %nodes) {
		my @tmp = @{$nodes{$node}->{'pods'}};
		while (($number > 0) and (scalar(@tmp) > 1)) {
			$hash{$tmp[0]} = $tmp[1];
            #print "\t\t$tmp->[0] ---> $tmp->[1]\n";
			shift @tmp;
			$number--;
		}
	}
		
    return %hash;
}

sub randomNodePairs {
    my $number = shift;
    my %hash = (); 
    
	my @tmp = keys %nodes;
	
    return %hash if (scalar(@tmp) < 2);
	
	if (scalar(@tmp) == 2) {
		$hash{$tmp[0]} = $tmp[1];
		$hash{$tmp[1]} = $tmp[0];
		return %hash;
	}

	if (scalar(@tmp) == 3) {
		$hash{$tmp[0]} = $tmp[1];
		$hash{$tmp[1]} = $tmp[0];
		$hash{$tmp[1]} = $tmp[2];
		$hash{$tmp[0]} = $tmp[2];
		return %hash;
	}
	
	if (scalar(@tmp) == 4) {
		$hash{$tmp[0]} = $tmp[1];
		$hash{$tmp[0]} = $tmp[2];
		$hash{$tmp[0]} = $tmp[3];
		$hash{$tmp[1]} = $tmp[2];
		$hash{$tmp[2]} = $tmp[3];
		return %hash;
	}

	while (($number > 0) and (scalar(@tmp) > 1)) {
		$hash{$tmp[0]} = $tmp[1];
		shift @tmp;
		$number--;
	}
		
    return %hash;
}


sub randomPodsOnDiffernetNodes {
    my %nodePairs = @_;
    my %hash = ();

	foreach my $nodeA (keys %nodePairs) {
		my @tmpA = @{$nodes{$nodeA}->{'pods'}};
		my @tmpB = @{$nodes{$nodePairs{$nodeA}}->{'pods'}};
		
		my $podA = $tmpA[rand @tmpA];
		my $podB = $tmpB[rand @tmpB];
		$hash{$podA} = $podB;
	}

	return %hash;
}

sub getKubernetesInfo {

	#get name of all nodes in the cluster
	my $allNodes = `kubectl get nodes -o name`;
	foreach (split("\n", $allNodes)) {
		#this will be the temporary variable to store all relevant Node data
		my %tmp = ();
		
		#add array for future POD information
		my @podsOnThisNode = ();
		$tmp{'pods'} = \@podsOnThisNode;
			
		$_ =~ s/node\///;
		print STDERR "Node: $_\n";
		
		#get all the information on this particular Nodes
		my $res = `kubectl describe node $_`;
		foreach my $line (split("\n", $res)) {
			#get IPaddress of the Node
			if ($line =~ /InternalIP:.*?($IPregexp)/) {
				$tmp{'IPaddress'} = $1;
			}
			
			#get PodCIDR of the Node 
			if ($line =~ /PodCIDR:.*?($IPregexp\/\d+)/) {
				$tmp{'PodCIDR'} = $1;
			}
			
		}
		$nodes{$_} = \%tmp;
	}


	#get name of all pods in the cluster
	my $allPods = `kubectl get pods -o=custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace | grep netperf`;
	foreach (split("\n", $allPods)) {
		#next if ($_ =~ /NAMESPACE/); #just skip the first header line
		
		#this will be the temporary variable to store all relevant POD data
		my %tmp = ();
		
		my ($name, $namespace) = split(/ +/, $_);
		print STDERR "Pod: $name  in  $namespace \n";
		$tmp{'namespace'} = $namespace;
		
		#get all the information on this particular Nodes
		my $res = `kubectl describe pod $name --namespace=$namespace`;
		foreach my $line (split("\n", $res)) {
			#get IPaddress of the POD
			if ($line =~ /IP:.*?($IPregexp)/) {
				$tmp{'IPaddress'} = $1;
			}
			
			#get the Node that the POD is running on
			if ($line =~ /Node: +(.*?)\/($IPregexp)/) {
				$tmp{'NodeName'} = $1;
				$tmp{'NodeIP'} = $2;            
			}
		}
		#if this POD runs in host mode, we add it to the node
		if ($tmp{'IPaddress'} eq $tmp{'NodeIP'}) {
			$nodes{$tmp{'NodeName'}}->{'HostNetPerf'} = $name;
		}	
		#adding the same POD to the Node's list and to the POD list
		else {
			push @{$nodes{$tmp{'NodeName'}}->{'pods'}}, $name;
			$pods{$name} = \%tmp;
		}	
		
	}

	#get all info on NetPerf service
	my $allServices = `kubectl get services --all-namespaces -o wide | grep netperf`;
	foreach (split("\n", $allServices)) {
		next if ($_ =~ /NAMESPACE/); #just skip the first header line
		
		#this will be the temporary variable to store all relevant POD data
		my %tmp = ();
		
		my @podBackends = ();
		
		my ($namespace, $name, $type, $clusterIP, $externalIP, $port, $age, $selector) = split(/ +/, $_);
		print STDERR "service: $name  in  $namespace IP=$clusterIP $externalIP $selector \n";
		$tmp{'namespace'} = $namespace;
		$tmp{'type'} = $type;
		$tmp{'clusterIP'} = $clusterIP;
		$tmp{'externalIP'} = $externalIP;
		$tmp{'selector'} = $selector;
		
		
		#get all the POD backends for this service
		my $res = `kubectl get pods -l $selector --all-namespaces -o name`;
		foreach my $line (split("\n", $res)) {
			$line =~ s/pods\///;
			push @podBackends, $line;
		}
		$tmp{'podBackends'} = \@podBackends;
			
		$services{$name} = \%tmp;
	}

	#in order to get all the ports for the services we do a query in JSON
	my $json = `kubectl get services --all-namespaces -o json`;
	my $hash = parse_json ($json);
	#print ref $hash, "\n";

	foreach my $svc (@{$hash->{'items'}}) {
		#print $svc->{'metadata'}->{'name'}, '   ', $svc->{'spec'}->{'ports'}, "\n";
		next unless (defined($services{$svc->{'metadata'}->{'name'}}));
		$services{$svc->{'metadata'}->{'name'}}->{'ports'} = $svc->{'spec'}->{'ports'};
	}

	print STDERR join(' ',%nodes),"\n";
	print STDERR join(' ',%pods),"\n";
	print STDERR join(' ',%services),"\n";
}
