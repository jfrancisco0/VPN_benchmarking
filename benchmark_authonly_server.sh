#!/bin/bash

#---------------OpenVPN secure server and Wireguard benchmarks---------------------#

#Check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

root_dir=/home/pi
results_path=$root_dir/results_server/benchmark_authonly

#Set variable to use in filenames
i=1

#Make trap to ensure clean exit
trap "killall -s INT openvpn iperf3 top tcpdump; wg-quick down $root_dir/wg0.conf >> $results_path/logs/service_wg-$i.log 2>&1; echo 'Child processes killed, exiting'; exit 0" SIGINT SIGTERM

#Avoid overwriting existing files - increment counter in name
name=$results_path/logs/iperf.log
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

#Start iperf3 server
iperf3 -s > $target 2>&1 &

echo 'iPerf3 server initiated'

#Start OpenVPN service
openvpn --config $root_dir/authonly_server.conf > $results_path/logs/service_ovpn-$i.log 2>&1 &

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

echo "Script running, you can now call the script in the client. Terminate with Ctrl+C"

while :			# This is the same as "while true".
do
        sleep 60	# This script is not really doing anything.
done
