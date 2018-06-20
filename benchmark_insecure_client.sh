#!/bin/bash

#---------------------OpenVPN secure client and Wireguard benchmarks--------------------#

#Check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

root_dir=/home/pi
results_path=$root_dir/results_client/benchmark_insecure

server_ip='10.0.20.2'
server_ovpn='10.8.0.1'
server_wg='10.0.0.2'

#Set variable to use in filenames
i=1

#Make trap to ensure clean exit
trap "killall -s INT openvpn iperf3 top tcpdump; wg-quick down $root_dir/wg0.conf >> $results_path/logs/service_wg-$i.log 2>&1; echo 'Child processes killed, exiting'; exit 0" SIGINT SIGTERM

#Avoid overwriting existing files - increment counter in name
name=$results_path/logs/service_ovpn.log
path=$(dirname "$name")
filename=$(basename "$name")
extension="${filename##*.}"
filename="${filename%.*}"
if [[ -e $path/$filename.$extension ]] ; then
    i=2
    while [[ -e $path/$filename-$i.$extension ]] ; do
        let i++
    done
    filename=$filename-$i
fi
target=$path/$filename.$extension

#Start OpenVPN service
openvpn --ncp-disable --config $root_dir/insecure_client.conf > $target 2>&1 &

echo 'OpenVPN started'

#Start WireGuard service
wg-quick up $root_dir/wg0.conf > $results_path/logs/service_wg-$i.log 2>&1 &

echo 'WireGuard started'
echo 'Waiting for full setup - Sleeping 4 secs'
sleep 4

#Start collecting packets from OpenVPN interface
#tcpdump -w $results_path/pcap/tun0-$i.pcap -i tun0 > /dev/null 2>&1 &

#echo 'Capture started on tun0'

#Start collecting packets from WireGuard interface
#tcpdump -w $results_path/pcap/wg0-$i.pcap -i wg0 > /dev/null 2>&1 &

#echo 'Capture started on wg0'

#Start recording CPU usage
top -b | awk '/%Cpu/ {print strftime("%H:%M:%S"), $0}' > $results_path/logs/cpu_total-$i.log 2>&1 &

echo 'Monitoring of CPU usage started'

#Start latency tests
ping -w 20 $server_ip > $results_path/logs/latency_eth-$i.log 2>&1 &
echo 'Testing latency without VPN (20 seconds)'
sleep 21

ping -w 20 $server_ovpn > $results_path/logs/latency_ovpn-$i.log 2>&1 &
echo 'Testing latency with OpenVPN (20 seconds)'
sleep 21

ping -w 20 $server_wg > $results_path/logs/latency_wg-$i.log 2>&1 &
echo 'Testing latency with WireGuard (20 seconds)'
sleep 21

#Start iperf3 tests
date +"%T" > $results_path/logs/iperfTCP_eth-$i.log
iperf3 -c $server_ip -t 60 --logfile $results_path/logs/iperfTCP_eth-$i.log 2>&1 &
echo 'iPerf TCP test started with no VPN (60 seconds)'
sleep 64

date +"%T" > $results_path/logs/iperfTCP_ovpn-$i.log
iperf3 -c $server_ovpn -t 60 --logfile $results_path/logs/iperfTCP_ovpn-$i.log 2>&1 &
echo 'iPerf TCP test started on OpenVPN interface (60 seconds)'
sleep 64

date +"%T" > $results_path/logs/iperfTCP_wg-$i.log
iperf3 -c $server_wg -t 60 --logfile $results_path/logs/iperfTCP_wg-$i.log 2>&1 &
echo 'iPerf TCP test started on WireGuard interface (60 seconds)'
sleep 64

echo "Script finished, terminate with Ctrl+C"

while :			# This is the same as "while true".
do
	sleep 60	# This script is not really doing anything.
done
