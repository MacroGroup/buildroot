#!/bin/bash

readonly PCIE_MIN_SPEED=100

check_dependencies_pci() {
	for i in fio jq lspci nvme; do
		if ! command -v "$i" &>/dev/null; then
			echo "Error: $i not installed"
			return 1
		fi
	done

	return 0
}

test_pci_device() {
	local device="$1"
	local pci_info=$(lspci -n -s "$device" 2>/dev/null)

	if [ -n "$pci_info" ]; then
		local pci_id=$(echo "$pci_info" | awk '{print $3}')
		if [ -n "$pci_id" ]; then
			echo "$pci_id"
		else
			echo "OK"
		fi
		return 0
	else
		echo "Missing"
		return 1
	fi
}

get_nvme_device() {
	local device="$1"
	local nvme_ctrl
	nvme_ctrl=$(grep -l "$device" /sys/class/nvme/*/address | cut -d/ -f5)

	if [ -z "$nvme_ctrl" ]; then
		echo "NVMe: Missing"
		return 2
	fi

	local nvme_dev="/dev/${nvme_ctrl}n1"

	if [ ! -b "$nvme_dev" ]; then
		nvme_dev=$(ls /dev/${nvme_ctrl}n* 2>/dev/null | head -n1)

		if [ -z "$nvme_dev" ] || [ ! -b "$nvme_dev" ]; then
			echo "NVMe: Missing"
			return 2
		fi
	fi

	if mount | grep -q "^${nvme_dev}"; then
		echo "NVMe: Mounted"
		return 2
	fi

	echo "$nvme_dev"

	return 0
}

get_pcie_speed() {
	local device="$1"
	local writetest="$2"

	local pcie_info
	pcie_info=$(lspci -vv -s "$device" 2>/dev/null | grep -E 'LnkSta:|LnkCap:')

	local speed=""
	local width=""
	local version=""

	while IFS= read -r line; do
		if [[ $line == *"LnkSta:"* ]]; then
			speed=$(echo "$line" | grep -oP 'Speed \K[0-9.]+GT/s')
			width=$(echo "$line" | grep -oP 'Width \Kx[0-9]+')
		elif [[ $line == *"LnkCap:"* ]]; then
			version=$(echo "$line" | grep -oP 'Port #\d, Speed \K[0-9.]+GT/s')
		fi
	done <<< "$pcie_info"

	local encoding_rate

	case "$version" in
	"2.5"|"5")
		encoding_rate=0.8
		;;
	"8"|"16"|"32")
		encoding_rate=0.9846
		;;
	*)
		encoding_rate=0.8
		;;
	esac

	local min_speed=$PCIE_MIN_SPEED
	if [[ -n "$speed" && -n "$width" ]]; then
		local speed_val=$(echo "$speed" | sed 's/GT\/s//')
		local width_val=$(echo "$width" | sed 's/x//')

		min_speed=$(bc <<< "scale=2; $speed_val * $width_val * $encoding_rate * 1000 / 8")
		# Use 90% effectivity, compare with half value
		min_speed=$(bc <<< "scale=2; $min_speed * 0.9 / 2")
	fi

	if $writetest; then
		# Use 80% of minimal speed for write
		min_speed=$(bc <<< "scale=2; $min_speed * 0.8")
	fi

	echo "$min_speed"
}

test_pci_read_speed_nvme() {
	local device="$1"
	local nvme_dev=$(get_nvme_device "$device")
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$nvme_dev"
		return $ret
	fi

	local read_output
	read_output=$(fio --name=read_test --filename="$nvme_dev" --rw=read \
		--bs=128k --iodepth=64 --runtime=2s --time_based --direct=1 \
		--ioengine=libaio --output-format=json 2>&1)

	if [ $? -ne 0 ]; then
		echo "NVMe: Error"
		return 1
	fi

	local read_speed
	read_speed=$(echo "$read_output" | jq -r '.jobs[0].read.bw' 2>/dev/null)

	if [[ ! "$read_speed" =~ ^[0-9.]+$ ]]; then
		echo "NVMe: Error"
		return 1
	fi

	read_speed=$(echo "scale=2; $read_speed / 1024" | bc)

	local min_read_speed=$(get_pcie_speed "$device" false)

	local result="${read_speed} MB/s"

	echo "NVMe: $result"

	if (( $(echo "$read_speed >= $min_read_speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_pci_write_speed_nvme() {
	local device="$1"
	local nvme_dev=$(get_nvme_device "$device")
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$nvme_dev"
		return $ret
	fi

	local write_output
	write_output=$(fio --name=write_test --filename="$nvme_dev" --rw=write \
		--bs=128k --iodepth=64 --runtime=2s --time_based --direct=1 \
		--ioengine=libaio --output-format=json 2>&1)

	if [ $? -ne 0 ]; then
		echo "NVMe: Error"
		return 1
	fi

	local write_speed
	write_speed=$(echo "$write_output" | jq -r '.jobs[0].write.bw' 2>/dev/null)

	if [[ ! "$write_speed" =~ ^[0-9.]+$ ]]; then
		echo "NVMe: Error"
		return 1
	fi

	write_speed=$(echo "scale=2; $write_speed / 1024" | bc)

	local min_write_speed=$(get_pcie_speed "$device" true)

	local result="${write_speed} MB/s"

	echo "NVMe: $result"
	if (( $(echo "$write_speed >= $min_write_speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_pci_read_speed_wlan() {
	local device="$1"

	echo "WLAN: Not implemented"

	return 2
}

test_pci_write_speed_wlan() {
	local device="$1"

	echo "WLAN: Not implemented"

	return 2
}

test_pci_read_speed_unknown() {
	local device="$1"
	local class_code="$2"

	echo "Unsupported: $class_code"

	return 2
}

test_pci_write_speed_unknown() {
	local device="$1"
	local class_code="$2"

	echo "Unsupported: $class_code"

	return 2
}

test_pci_read_speed() {
	local device="$1"

	if ! lspci -s "$device" &>/dev/null; then
		echo "Missing"
		return 2
	fi

	local class_info
	class_info=$(lspci -n -s "$device" | awk '{print $2}' | cut -d: -f1)

	local class_code=${class_info:0:2}

	case $class_code in
	"01")
		if [ "${class_info:2:2}" = "08" ]; then
			test_pci_read_speed_nvme "$device"
		else
			test_pci_read_speed_unknown "$device" "$class_info"
		fi
		;;
	"02")
		test_pci_read_speed_wlan "$device"
		;;
	*)
		test_pci_read_speed_unknown "$device" "$class_info"
		;;
	esac
}

test_pci_write_speed() {
	local device="$1"

	if ! lspci -s "$device" &>/dev/null; then
		echo "Missing"
		return 2
	fi

	local class_info
	class_info=$(lspci -n -s "$device" | awk '{print $2}' | cut -d: -f1)

	local class_code=${class_info:0:2}

	case $class_code in
	"01")
		if [ "${class_info:2:2}" = "08" ]; then
			test_pci_write_speed_nvme "$device"
		else
			test_pci_write_speed_unknown "$device" "$class_info"
		fi
		;;
	"02")
		test_pci_write_speed_wlan "$device"
		;;
	*)
		test_pci_write_speed_unknown "$device" "$class_info"
		;;
	esac
}

test_pci_bus_0() {
	test_pci_device "0000:00:00.0"
}

test_pci_device_0() {
	test_pci_device "0000:01:00.0"
}

test_pci_read_speed_0() {
	test_pci_read_speed "0000:01:00.0"
}

test_pci_write_speed_0() {
	test_pci_write_speed "0000:01:00.0"
}

test_pci_bus_1() {
	test_pci_device "0001:10:00.0"
}

test_pci_device_1() {
	test_pci_device "0001:11:00.0"
}

test_pci_read_speed_1() {
	test_pci_read_speed "0001:11:00.0"
}

test_pci_write_speed_1() {
	test_pci_write_speed "0001:11:00.0"
}

test_pci_bus_2() {
	test_pci_device "0002:20:00.0"
}

test_pci_device_2() {
	test_pci_device "0002:21:00.0"
}

test_pci_read_speed_2() {
	test_pci_read_speed "0002:21:00.0"
}

test_pci_write_speed_2() {
	test_pci_write_speed "0002:21:00.0"
}

check_pci_bus_presence() {
	local bus_test_func="$1"

	if $bus_test_func >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

check_pci_device_presence() {
	local device_test_func="$1"

	if $device_test_func >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

ds_rk3568_som_smarc_evb_test_pci() {
	if [ "$1" = "register" ]; then
		register_test "test_pci_bus_0" "PCI Bus 0"

		if check_pci_bus_presence test_pci_bus_0; then
			register_test "test_pci_device_0" "PCI Device 0"

			if check_pci_device_presence test_pci_device_0; then
				register_test "test_pci_read_speed_0" "PCI Device 0 Read"
				register_test "test_pci_write_speed_0" "PCI Device 0 Write"
			fi
		fi

		register_test "test_pci_bus_1" "PCI Bus 1"

		if check_pci_bus_presence test_pci_bus_1; then
			register_test "test_pci_device_1" "PCI Device 1"

			if check_pci_device_presence test_pci_device_1; then
				register_test "test_pci_read_speed_1" "PCI Device 1 Read"
				register_test "test_pci_write_speed_1" "PCI Device 1 Write"
			fi
		fi

		register_test "test_pci_bus_2" "PCI Bus 2"

		if check_pci_bus_presence test_pci_bus_2; then
			register_test "test_pci_device_2" "PCI Device 2"

			if check_pci_device_presence test_pci_device_2; then
				register_test "test_pci_read_speed_2" "PCI Device 2 Read"
				register_test "test_pci_write_speed_2" "PCI Device 2 Write"
			fi
		fi

		return 0
	fi

	if lspci &>/dev/null; then
		echo "OK"
		return 0
	else
		echo "Missing"
		return 1
	fi
}

if [ -f /proc/device-tree/compatible ]; then
	if check_dependencies_pci; then
		if grep -Eq 'diasom,ds-rk3568-som-smarc-evb' /proc/device-tree/compatible; then
			register_test "ds_rk3568_som_smarc_evb_test_pci" "PCI Core"
			return 0
		else
			echo "Error: Cannot find suitable devicetree compatible string"
		fi
	fi
else
	echo "Error: Script cannot be used without devicetree"
fi

return 1
