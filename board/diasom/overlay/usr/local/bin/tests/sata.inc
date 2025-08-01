#!/bin/bash

readonly SATA1_SPEED=150
readonly SATA2_MIN_SPEED="$SATA1_SPEED"

check_dependencies_sata() {
	local deps=(fio hdparm jq)
	check_dependencies "SATA" "${deps[@]}"
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

	echo -n ""

	return 1
}

check_sata_basic() {
	if ! dmesg | grep -i sata | grep -iq 'link up'; then
		echo "Missing"
		return 1
	fi

	local sata_dev=$(get_sata_device)

	if [ -z "$sata_dev" ] || [ ! -b "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	echo "$sata_dev"

	return 0
}

test_sata_read() {
	local speed="$1"
	local sata_info=$(check_sata_basic)
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$sata_info"
		return $ret
	fi


	local sata_dev=$(echo "$sata_info" | tail -1)

	if ! [ -b "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	local hdparm_output=$(hdparm -t "$sata_dev" 2>&1)

	local buffered_speed=$(echo "$hdparm_output" | awk '/Timing buffered disk reads/ {
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

test_sata_write() {
	local speed="$1"
	local sata_info=$(check_sata_basic)
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$sata_info"
		return $ret
	fi

	local sata_dev=$(echo "$sata_info" | tail -1)

	if ! [ -b "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	local fio_output
	fio_output=$(fio --name=write_test --filename="$sata_dev" --rw=write \
		--bs=1M --direct=1 --ioengine=libaio --size=10M --runtime=2 \
		--time_based --output-format=json 2>&1)

	if [ $? -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local write_speed
	write_speed=$(echo "$fio_output" | jq -r '.jobs[0].write.bw' 2>/dev/null)

	if [[ ! "$write_speed" =~ ^[0-9.]+$ ]]; then
		echo "Error"
		return 1
	fi

	write_speed=$(echo "scale=2; $write_speed / 1024" | bc)

	echo "$write_speed MB/s"

	if (( $(echo "$write_speed > $speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

ds_rk3568_som_smarc_evb_test_sata_read() {
	local speed="$SATA2_MIN_SPEED"

	test_sata_read "$speed"
}

ds_rk3568_som_smarc_evb_test_sata_write() {
	local speed=$(bc <<< "scale=2; $SATA2_MIN_SPEED * 0.8")

	test_sata_write "$speed"
}

if ! declare -F register_test > /dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if ! declare -F check_dependencies > /dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	if check_dependencies_sata; then
		if grep -Eq 'diasom,ds-rk3568-som-smarc-evb' /proc/device-tree/compatible; then
			register_test "ds_rk3568_som_smarc_evb_test_sata_read" "SATA Read"
			register_test "ds_rk3568_som_smarc_evb_test_sata_write" "SATA Write"

			return 0
		else
			echo "Error: Cannot find suitable devicetree compatible string"
		fi
	fi
else
	echo "Error: Script cannot be used without devicetree"
fi

return 1
