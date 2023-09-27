#!/bin/sh

for i in awk grep iw ip ifconfig; do
	if ! which $i >/dev/null 2>&1; then
		echo "Script cannot be executed due missing \"$i\" tool!"
		exit 1
	fi
done

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

[ -z $HW ] && { echo "Something going wrong. Quit now!"; exit 1; }

echo "Using Wireless interface: $IF, MAC address: $HW"

if [[ -z $(ifconfig | grep '$IF:') ]]; then
	echo "Estabilish link $IF"
	# Set link status
	ip link set $IF up || exit 1
else
	echo "Link $IF already present"
fi

# Get connection status
STATE=$(iw dev $IF link)
if [ "$STATE" = "Not connected." ]; then
	echo "Connect!"
else
	echo "State: $STATE"
fi

# TODO

exit 0
