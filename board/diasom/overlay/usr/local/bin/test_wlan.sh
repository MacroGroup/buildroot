#!/bin/sh

for i in awk dhclient grep ifconfig ip iw ping wpa_passphrase wpa_supplicant; do
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
	echo "Usage: $0 <SSID> <password>"
	exit 1
fi

SSID=$1
PASS=$2

# Get MAC address
HW=$(iw dev $IF info | grep 'addr' | awk '{print $2}')

[ -z $HW ] && { echo "Something going wrong. Quit now!"; exit 1; }

echo "Using Wireless interface: $IF, MAC address: $HW"

# Set link status
ip link set $IF up || exit 1

# Get list of SSIDs
echo "Avaiable SSIDs:"
iw dev $IF scan 2&>/dev/null | grep 'SSID:'

connected=false
for try in 1 2 3
do
	# Get connection status
	STATE=$(iw dev $IF link)
	if [ "$STATE" = "Not connected." ]; then
		echo "Try to connect: $try"
		wpa_supplicant -W -B -i $IF -c <(wpa_passphrase "$SSID" "$PASS")
		sleep 2
	else
		echo $STATE
		connected=true
		break
	fi
done

if [ "$connected" = true ]; then
	# Start DHCP client
	dhclient $IF
	sleep 2
else
	echo "Cannot connect to \"$SSID\"!"
	exit 1
fi

ADDR=$(ifconfig $IF | grep 'inet addr')
if [ -z "$ADDR" ]; then
	echo "Cannot get IP address!"
	exit 1
fi

# All done, now Ping!
ping -c 5 -I $IF 8.8.8.8

exit 0
