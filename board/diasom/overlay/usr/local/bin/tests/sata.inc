#!/bin/bash

check_dependencies_sata() {
	for i in bc hdparm; do
		if ! command -v "$i" &>/dev/null; then
			echo "Error: $i not installed"
			return 1
		fi
	done

	return 0
}

get_sata_device() {
	for dev in /sys/block/sd*; do
		[ -e "$dev" ] || continue
		dev_name=$(basename "$dev")

		if [ -f "$dev/device/type" ]; then
			type=$(cat "$dev/device/type")
			if [ "$type" != "0" ]; then
				continue
			fi
		fi

		if [ -f "$dev/device/vendor" ]; then
			vendor=$(cat "$dev/device/vendor")
			if [[ "$vendor" =~ [aA][tT][aA] ]]; then
				echo "/dev/$dev_name"
				return 0
			fi
		fi
	done

	return 1
}

test_sata() {
	local speed="$1"

	if ! dmesg | grep -i sata | grep -iq 'link up'; then
		echo "Error"
		return 1
	fi

	local sata_dev
	sata_dev=$(get_sata_device)

	if [ -z "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	if ! [ -b "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	local hdparm_output
	hdparm_output=$(hdparm -t "$sata_dev" 2>&1)

	local buffered_speed

	buffered_speed=$(echo "$hdparm_output" | awk '/Timing buffered disk reads/ {
		if ($(NF) == "kB/s") {
			print $(NF-1)/1000
		} else if ($(NF) == "MB/s") {
			print $(NF-1)
		} else {
			print $(NF)
		}
	}')

	if [[ ! "$buffered_speed" =~ ^[0-9.]+$ ]]; then
		echo "Error"
		return 1
	fi

	echo "$buffered_speed MB/s"
	if (( $(echo "$buffered_speed > $speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

ds_rk3568_som_smarc_evb_test_sata() {
	if [ "$1" = "register" ]; then
		return 0
	fi

	test_sata 150
}

if [ -f /proc/device-tree/compatible ]; then
	if check_dependencies_sata; then
		if grep -Eq 'diasom,ds-rk3568-som-smarc-evb' /proc/device-tree/compatible; then
			register_test "ds_rk3568_som_smarc_evb_test_sata" "SATA"
			return 0
		else
			echo "Error: Cannot find suitable devicetree compatible string"
		fi
	fi
else
	echo "Error: Script cannot be used without devicetree"
fi

return 1
