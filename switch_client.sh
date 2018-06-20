#!/bin/bash

#-----------------AP switching test - client sends pings (client)----------------#

#Check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

server_ip='52.58.108.87'
server_ovpn='10.8.0.1'
server_wg='10.0.0.2'

root_dir=/home/pi
results_path=$root_dir/results_client/switch

#Switch interface via low metric route replacement
switch_eth='ip route replace default via 10.0.10.1 metric 1'
switch_wifi='ip route replace default via 192.168.200.1 metric 1'
switch_cel='ip route replace default via 78.137.225.1  metric 1'
echo 'For the tests to work, please make sure device is connected both over Ethernet, WiFi and Cel'

#Set variable to use in filenames
i=1

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

#Make trap to ensure clean exit
trap "$switch_eth; killall -s INT openvpn tcpdump; wg-quick down $root_dir/wg0.conf >> $results_path/logs/service_wg-$i.log 2>&1; echo 'Child processes killed, exiting'; exit 0" SIGINT SIGTERM

#Start OpenVPN service
openvpn $root_dir/client.conf > $target 2>&1 &

echo 'OpenVPN started'

#Start WireGuard service
wg-quick up $root_dir/wg0.conf > $results_path/logs/service_wg-$i.log 2>&1 &

echo 'WireGuard started'
echo 'Waiting for full setup - Sleeping 4 secs'
sleep 4

#Start packet capture on Wifi and Mobile
tcpdump -w $results_path/pcap/wwan0-$i.pcap -i wwan0 > /dev/null 2>&1  &
tcpdump -w $results_path/pcap/wlan0-$i.pcap -i wlan0 > /dev/null 2>&1  &

echo 'Capture started on wlan and wwan'

$switch_wifi

#Start latency tests

#No VPN over Wifi
ping -w 15 -i 0.005 $server_ip > $results_path/logs/latency_novpn-$i.log 2>&1 &

echo 'Sending pings every 5ms | Wifi without VPN (5 seconds)'
sleep 5

#Switch to Mobile
$switch_cel

echo 'Sending pings every 5ms | Mobile without VPN (5 seconds)'
sleep 5

#Return to Wifi
$switch_wifi
echo 'Sending pings every 5ms | Wifi without VPN (5 seconds)'
sleep 5

#OpenVPN
ping -w 15 -i 0.005 $server_ovpn > $results_path/logs/latency_ovpn-$i.log 2>&1 &

#OpenVPN over Wifi
echo 'Sending pings every 5ms | Wifi with OpenVPN (5 seconds)'
sleep 5

#OpenVPN switch to Mobile
$switch_cel

echo 'Sending pings every 5ms | Mobile with OpenVPN (5 seconds)'
sleep 5

#OpenVPN return to Wifi
$switch_wifi
echo 'Sending pings every 5ms | Wifi with OpenVPN (5 seconds)'
sleep 5

#WireGuard
ping -w 15 -i 0.005 $server_wg > $results_path/logs/latency_wg-$i.log 2>&1 &

#WireGuard over Wifi
echo 'Sending pings every 5ms | Wifi with WireGuard (5 seconds)'
sleep 5

#Wireguard switch to Mobile
$switch_cel

echo 'Sending pings every 5ms | Mobile with WireGuard (5 seconds)'
sleep 5

#WireGuard return to Wifi
$switch_wifi

echo 'Sending pings every 5ms | Wifi with WireGuard (5 seconds)'
sleep 5

$switch_eth

echo "Script finished, terminate with Ctrl+C"

while :			# This is the same as "while true".
do
	sleep 60	# This script is not really doing anything.
done
