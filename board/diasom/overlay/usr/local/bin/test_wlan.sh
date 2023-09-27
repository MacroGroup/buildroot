#!/bin/sh

# Get interface name
IF=$(iw dev | grep 'Interface' | awk '{print $2}')

[ -z $IF ] && { echo "Wireless interface is not found!"; exit 1; }

# Check arguments
if [ $# -ne 2 ]; then
	# TODO
	# exit 1
fi

#SSID=$1
#PASS=$2

# Get MAC address
HW=$(iw dev $IF info | grep 'addr' | awk '{print $2}')

echo "Using Wireless interface: $IF, MAC address: $HW"

# Set link status
ip link set $IF up

# Get connection status
STATE=$(iw dev $IF link)
if [ "$STATE" = "Not connected." ]; then
	echo "Connect!"
else
	echo "State: $STATE"
fi

# TODO

exit 0
