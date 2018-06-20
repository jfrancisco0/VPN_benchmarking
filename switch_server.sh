#!/bin/bash

#--------------AP switching test - client sends pings (server)----------------------#

#Check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

root_dir=/home/ubuntu
results_path=$root_dir/results_server/switch

#Set variable to use in filenames
i=1

#Make trap to ensure clean exit
trap "killall -s INT openvpn tcpdump; wg-quick down $root_dir/wg0.conf >> $results_path/logs/service_wg-$i.log 2>&1; echo 'Child processes killed, exiting'; exit 0" SIGINT SIGTERM

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
openvpn $root_dir/server.conf > $target 2>&1 &

echo 'OpenVPN started'

#Start WireGuard service
wg-quick up $root_dir/wg0.conf > $results_path/logs/service_wg-$i.log 2>&1 &

echo 'WireGuard started'

#Start packet capture on eth
tcpdump -w $results_path/pcap/eth0-$i.pcap -i eth0 > /dev/null 2>&1  &

echo 'Capture started on eth0'

echo 'Waiting for full setup - Sleeping 4 secs'
sleep 4

echo "Script running, you can now call the script in the client. Terminate with Ctrl+C"

while :			# This is the same as "while true".
do
        sleep 60	# This script is not really doing anything.
done
