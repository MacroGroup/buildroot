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

exit 0
