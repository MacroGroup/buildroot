#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2181,SC2034
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -A USB_DT_MAP=(
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_usb"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_test_usb"
	["diasom,ds-rk3588-btb"]=""
	["diasom,ds-rk3588-btb-evb"]="ds_rk3588_btb_evb_test_usb"
)

declare -A USB_DISABLE_TESTS

check_dependencies_usb() {
	local deps=("${DEV_DEPS[@]}")
	deps+=(@dev_modprobe bt-adapter fio jq mkfifo xargs)
	check_dependencies "USB" "${deps[@]}"
}

check_dependencies_usb_default() {
	local deps=(xargs)
	check_dependencies "USB" "${deps[@]}"
}

test_usb_get_device_id() {
	local device_path="$1"
	local vid_file="${device_path}/idVendor"
	local pid_file="${device_path}/idProduct"

	if [ ! -f "$vid_file" ] || [ ! -f "$pid_file" ]; then
		return 1
	fi

	local vendor product
	vendor=$(cat "$vid_file" 2>/dev/null)
	product=$(cat "$pid_file" 2>/dev/null)

	if [ -z "$vendor" ] || [ -z "$product" ]; then
		return 1
	fi

	echo "${vendor}:${product}"

	return 0
}

test_usb_device() {
	local device="$1"
	local info="${2:-""}"
	local device_path="/sys/bus/usb/devices/$device"

	if [ -d "$device_path" ]; then
		if test_usb_get_device_id "$device_path" >/dev/null 2>&1; then
			local ids
			ids=$(test_usb_get_device_id "$device_path")
			if [ -z "$info" ]; then
				echo "$ids"
			else
				echo "$ids ($info)"
			fi
			return 0
		else
			echo "OK"
			return 0
		fi
	fi

	echo "Missing"

	return 1
}

test_usb_get_class() {
	local device="$1"
	local device_path="/sys/bus/usb/devices/$device"

	local class_file="${device_path}/bDeviceClass"
	local subclass_file="${device_path}/bDeviceSubClass"
	local protocol_file="${device_path}/bDeviceProtocol"

	if [[ -f "$class_file" && -f "$subclass_file" && -f "$protocol_file" ]]; then
		local class subclass protocol
		class=$(cat "$class_file" 2>/dev/null)
		subclass=$(cat "$subclass_file" 2>/dev/null)
		protocol=$(cat "$protocol_file" 2>/dev/null)

		if [[ -n "$class" && "$class" != "00" && "$class" != "ef" ]]; then
			echo "${class}:${subclass}:${protocol}"
			return 0
		fi
	fi

	for iface in "${device_path}":*; do
		[[ -d "$iface" ]] || continue

		local if_class_file="${iface}/bInterfaceClass"
		local if_subclass_file="${iface}/bInterfaceSubClass"
		local if_protocol_file="${iface}/bInterfaceProtocol"

		if [[ -f "$if_class_file" && -f "$if_subclass_file" && -f "$if_protocol_file" ]]; then
			local if_class if_subclass if_protocol
			if_class=$(cat "$if_class_file" 2>/dev/null)
			if_subclass=$(cat "$if_subclass_file" 2>/dev/null)
			if_protocol=$(cat "$if_protocol_file" 2>/dev/null)

			if [[ -n "$if_class" && "$if_class" != "00" ]]; then
				echo "${if_class}:${if_subclass}:${if_protocol}"
				return 0
			fi
		fi
	done

	if [[ -n "$class" && "$class" != "00" ]]; then
		echo "${class}:${subclass}:${protocol}"
		return 0
	fi

	echo -n ""

	return 1
}

test_usb_get_block_device() {
	local device="$1"
	local device_path="/sys/bus/usb/devices/$device"
	local block_dev=""

	local real_device_path
	real_device_path=$(readlink -f "$device_path")

	for block in /sys/block/sd*; do
		local block_name block_device_path
		block_name=$(basename "$block")
		block_device_path=$(readlink -f "$block/device")

		if [[ "$block_device_path" == *"$real_device_path"* ]]; then
			block_dev="/dev/$block_name"
			break
		fi
	done

	if [[ -z "$block_dev" ]]; then
		echo "MS: Missing"
		return 2
	fi

	echo "$block_dev"

	return 0
}

test_usb_read_speed_ms() {
	local device="$1"
	local block_dev
	block_dev=$(test_usb_get_block_device "$device")
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$block_dev"
		return $ret
	fi

	local speed_file="/sys/bus/usb/devices/$device/speed"
	local host_speed=""
	local max_speed_bps=0

	if [ -f "$speed_file" ]; then
		host_speed=$(cat "$speed_file" 2>/dev/null)
		max_speed_bps=$(bc <<< "scale=2; $host_speed * 1000000")
	fi

	local fio_output
	fio_output=$(fio --name=read_test --filename="$block_dev" --rw=read \
		--ioengine=libaio --direct=1 --bs=64k --iodepth=8 \
		--size=64M --runtime=2 --time_based --group_reporting \
		--output-format=json 2>/dev/null)

	local read_speed max_speed_mbs min_speed
	if read_speed=$(echo "$fio_output" | jq -r '.jobs[0].read.bw'); then
		read_speed_mbs=$(echo "scale=2; $read_speed * 1024 / 1000000" | bc -l | awk '{printf "%.2f", $1}')

		if [ "$max_speed_bps" -gt 0 ]; then
			max_speed_mbs=$(echo "scale=2; $max_speed_bps / 8000000" | bc)
			# Use 8/10 coding, 55% effectivity, compare with half value
			min_speed=$(echo "scale=2; $max_speed_mbs * 0.8 * 0.55 / 2" | bc)

			echo "MS: ${read_speed_mbs} MB/s"

			if (( $(echo "$read_speed_mbs > $min_speed" | bc -l) )); then
				return 0
			else
				return 2
			fi
		fi
	fi

	echo "MS: Error"

	return 1
}

test_usb_read_speed_bt() {
	local device="$1"
	local device_path real_device_path capture_pid traffic_pid killer_pid
	device_path="/sys/bus/usb/devices/$device"
	real_device_path=$(readlink -f "$device_path")
	local hci_index=""
	local fifo=""
	local powered_by_us=0

	local power_file="${real_device_path}/power/runtime_status"
	if [[ -f "$power_file" ]]; then
		local power_status
		power_status=$(cat "$power_file" 2>/dev/null)
		if [[ "$power_status" != "active" ]]; then
			echo "BT: Suspended"
			return 2
		fi
	fi

	for hci in /sys/class/bluetooth/hci*; do
		local hci_device_path base_hci_path
		hci_device_path=$(readlink -f "$hci/device")
		base_hci_path=$(dirname "$hci_device_path")

		if [[ "$base_hci_path" == "$real_device_path" ]]; then
			hci_index=${hci##*hci}
			break
		fi
	done

	if [[ -z "$hci_index" ]]; then
		echo "BT: Interface not found (Unsupported card?)"
		return 2
	fi

	local powered_initial
	powered_initial=$(bt-adapter -a "hci$hci_index" -i | awk '/Powered:/ {print $2}')

	if [[ "$powered_initial" != "1" ]]; then
		if ! bt-adapter -a "hci$hci_index" --set Powered 1 &>/dev/null; then
			echo "BT: Activation failed"
			return 2
		fi
		sleep 2
		powered_by_us=1
	fi

	cleanup() {
		[[ -n "$capture_pid" ]] && kill "$capture_pid" &>/dev/null
		[[ -n "$traffic_pid" ]] && kill "$traffic_pid" &>/dev/null
		[[ -n "$killer_pid" ]] && kill "$killer_pid" &>/dev/null

		[[ -n "$fifo" && -p "$fifo" ]] && rm -f "$fifo"

		if [[ -n $hci_index && $powered_by_us -eq 1 ]]; then
			bt-adapter -a "hci$hci_index" --set Powered 0 &>/dev/null
			powered_by_us=0
		fi
	}
	trap cleanup EXIT RETURN INT TERM HUP

	if [[ ! -f "$device_path/busnum" || ! -f "$device_path/devnum" ]]; then
		echo "BT: Error getting bus/dev numbers"
		return 2
	fi

	local bus devnum
	bus=$(<"$device_path/busnum")
	devnum=$(<"$device_path/devnum")

	local usbmon_path="/sys/kernel/debug/usb/usbmon/${bus}u"
	dev_modprobe "usbmon" "$usbmon_path" &>/dev/null
	if [[ $? -ne 0 ]]; then
		echo "BT: usbmon interface missing"
		return 2
	fi

	fifo=$(mktemp -u)
	if ! mkfifo "$fifo"; then
		echo "BT: Failed to create FIFO"
		return 2
	fi

	timeout 15 cat "$usbmon_path" > "$fifo" &
	capture_pid=$!
	sleep 1

	(
		for i in {1..1000}; do
			bt-adapter -a "hci$hci_index" -i >/dev/null
			bt-adapter -a "hci$hci_index" --set Discoverable 1 >/dev/null 2>&1
			bt-adapter -a "hci$hci_index" --set Pairable 1 >/dev/null 2>&1
			bt-adapter -a "hci$hci_index" --set Alias "TestDevice$i" >/dev/null 2>&1
		done
	) >/dev/null 2>&1 &
	traffic_pid=$!

	(
		wait $traffic_pid 2>/dev/null
		sleep 3
		kill $capture_pid 2>/dev/null
	) &
	killer_pid=$!

	local total_bytes=0
	local packet_count=0
	local start_time end_time duration
	start_time=$(date +%s.%N)

	while IFS= read -r -t 5 line; do
		[[ -z "$line" ]] && continue

		read -ra fields <<<"$line"
		[[ ${#fields[@]} -lt 6 ]] && continue

		[[ "${fields[2]}" != "C" ]] && continue

		if [[ "${fields[3]}" =~ ^([A-Za-z]{2}):([0-9]+):([0-9]+):([0-9]+)$ ]]; then
			local bus_val=$((10#${BASH_REMATCH[2]}))
			local dev_val=$((10#${BASH_REMATCH[3]}))

			[[ "$bus_val" -ne "$bus" || "$dev_val" -ne "$devnum" ]] && continue

			local status_field="${fields[4]}"
			local status_code="${status_field%%:*}"
			[[ "$status_code" != "0" ]] && continue

			if [[ "${fields[5]}" =~ ^[0-9]+$ ]]; then
				local bytes=${fields[5]}
				((total_bytes += bytes))
				((packet_count++))
			fi
		fi
	done < "$fifo"

	end_time=$(date +%s.%N)
	duration=$(echo "$end_time - $start_time" | bc)

	if (( $(echo "$duration < 0.1" | bc -l) )); then
		duration=0.1
	fi

	local speed_kbps
	speed_kbps=$(echo "scale=2; $total_bytes * 8 / $duration / 1000" | bc)
	[[ -z "$speed_kbps" ]] && speed_kbps=0

	printf "BT: %.2f Kbps" "$speed_kbps"
	if (( $(echo "$speed_kbps > 10" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_usb_read_speed_wlan() {
	local device="$1"
	local class_info="$2"

	echo "Unsupported: WLAN: $device:$class_info"

	return 2
}

test_usb_read_speed_unknown() {
	local device="$1"
	local class_info="$2"

	echo "Unsupported: $device:$class_info"

	return 2
}

test_usb_read_speed() {
	local device="$1"
	local class_info class subclass protocol
	class_info=$(test_usb_get_class "$device")
	class=$(echo "$class_info" | cut -d: -f1)
	subclass=$(echo "$class_info" | cut -d: -f2)
	protocol=$(echo "$class_info" | cut -d: -f3)

	case "$class" in
	"08")
		test_usb_read_speed_ms "$device"
		;;
	"03")
		echo "HID (skipped)"
		return 0
		;;
	"11")
		echo "Interface Association (skipped)"
		return 0
		;;
	"e0")
		if [ "$subclass" = "01" ] && [ "$protocol" = "01" ]; then
			test_usb_read_speed_bt "$device"
		else
			test_usb_read_speed_wlan "$device" "$class_info"
		fi
		;;
	"ff")
		test_usb_read_speed_wlan "$device" "$class_info"
		;;
	*)
		test_usb_read_speed_unknown "$device" "$class_info"
		;;
	esac
}

test_usb_find_devices() {
	local value="${1:-}"

	local usb_hubs=()

	local platform_dev=""
	if [ -n "$value" ]; then
		for dev in /sys/devices/platform/*; do
			if [[ -d "$dev" && "$(basename "$dev")" == *"$value"* ]]; then
				platform_dev="$dev"
				break
			fi
		done

		[[ -z "$platform_dev" ]] && { echo -n ""; return; }
	fi

	for usb_dev in /sys/bus/usb/devices/usb*; do
		[[ -d "$usb_dev" ]] || continue

		local usb_name device_path
		usb_name=$(basename "$usb_dev")
		if [[ ! "$usb_name" =~ ^usb[0-9]+$ ]]; then
			continue
		fi

		if [ -n "$platform_dev" ]; then
			device_path=$(readlink -f "$usb_dev/device")
			if [[ "$device_path" == "$platform_dev"* ]]; then
				usb_hubs+=("$usb_name")
			fi
		else
			usb_hubs+=("$usb_name")
		fi
	done

	echo "${usb_hubs[*]}"
}

test_usb_check_expected_device() {
	local vid="$1"
	local pid="$2"

	for device in /sys/bus/usb/devices/*; do
		if [ ! -d "$device" ]; then
			continue
		fi

		local ids
		ids=$(test_usb_get_device_id "$device")
		if [ $? -ne 0 ]; then
			continue
		fi

		local cur_vid=${ids%%:*}
		local cur_pid=${ids#*:}
		if [ "$cur_vid" == "$vid" ] && [ "$cur_pid" == "$pid" ]; then
			echo "Present"
			return 0
		fi
	done

	echo "Missing"

	return 1
}

test_usb_register_expected_devices_tests() {
	local -n devices_array="$1"

	local index=0
	for device_spec in "${devices_array[@]}"; do
		IFS=':' read -r vid pid description <<< "$device_spec"

		local test_func="test_expected_device_$index"
		eval "$test_func() {
			test_usb_check_expected_device \"$vid\" \"$pid\" \"$description\"
		}"
		register_test "$test_func" "Checking USB Device $description"

		((index++))
	done
}

test_usb_get_port_number() {
	local device="$1"
	local port_path="/sys/bus/usb/devices/$device/port"

	if [ -L "$port_path" ]; then
		local link
		link=$(readlink "$port_path")
		echo "$link" | grep -oE '[^/-]+$' | sed 's/[^0-9]*//g'
	else
		echo "Unknown"
	fi
}

test_usb_register_single_device() {
	local device="$1"
	local level="$2"
	local safe_addr="$3"
	local port_index="$4"
	local device_index="$5"

	if [ ! -f "/sys/bus/usb/devices/$device/idVendor" ] || [ ! -f "/sys/bus/usb/devices/$device/idProduct" ]; then
		return 1
	fi

	local full_index port_number class_info class
	full_index="${safe_addr}_${port_index}_${device_index}"
	port_number=$(test_usb_get_port_number "$device")

	class_info=$(test_usb_get_class "$device")
	class=$(echo "$class_info" | cut -d: -f1)

	if [ "$class" = "09" ]; then
		local test_dev_func="test_usb_device_$full_index"
		eval "$test_dev_func() { test_usb_device \"$device\" \"Hub\"; }"
		register_test "$test_dev_func" "USB Device Port $((port_number))" "$level"

		test_usb_register_hub_tests "$device" "$level" "$safe_addr" "${port_index}_${device_index}"
	else
		local test_dev_func="test_usb_device_$full_index"
		eval "$test_dev_func() { test_usb_device \"$device\"; }"
		register_test "$test_dev_func" "USB Device Port $((port_number))" "$level"

		if [ -z "${USB_DISABLE_TESTS[*]}" ]; then
			local test_read_func="test_usb_read_speed_$full_index"
			eval "$test_read_func() { test_usb_read_speed \"$device\"; }"
			register_test "$test_read_func" "USB Device Port $((port_number)) I/O" "$level"
		fi
	fi

	return 0
}

test_usb_register_hub_tests() {
	local hub_device="$1"
	local level="$2"
	local safe_addr="$3"
	local port_index="$4"

#	local hub_num_ports=$(cat "/sys/bus/usb/devices/$hub_device/num_ports" 2>/dev/null)

	local device_index=0
	while IFS= read -r -d $'\0' dev; do
		local dev_name
		dev_name=$(basename "$dev")
		[[ "$dev_name" == "$hub_device" ]] && continue

		if [[ "$dev_name" == *:* ]]; then
			continue
		fi

		if test_usb_register_single_device "$dev_name" "$((level + 1))" "$safe_addr" "$port_index" "$device_index"; then
			((device_index++))
		fi
	done < <(find /sys/bus/usb/devices -maxdepth 1 -name "$hub_device.*" -print0 2>/dev/null)
}

test_usb_register_tests() {
	local name="${1:-}"
	local addr="${2:-}"

	local root_ports
	root_ports=$(test_usb_find_devices "$addr")
	[[ -z "$root_ports" ]] && return

	local safe_addr
	if [ -z "$addr" ]; then
		safe_addr="default"
	else
		safe_addr="${addr//[^[:alnum:]]/_}"
	fi

	IFS=' ' read -ra ports_array <<< "$root_ports"

	local port_index=0
	for root_port in "${ports_array[@]}"; do
		local controller_type="Unknown"
		local speed_file="/sys/bus/usb/devices/$root_port/speed"
		if [[ -f "$speed_file" ]]; then
			local speed_val
			speed_val=$(cat "$speed_file" 2>/dev/null)
			case $speed_val in
			12)
				controller_type="OHCI"
				;;
			480)
				controller_type="EHCI"
				;;
			5000|10000|20000)
				local speed_gbs=$((speed_val / 1000))
				controller_type="XHCI (${speed_gbs} Gb/s)"
				;;
			*)
				;;
			esac
		fi

		local test_bus_func="test_usb_bus_${safe_addr}_${port_index}"
		eval "$test_bus_func() { test_usb_device \"$root_port\" \"Root Hub\"; }"
		if [ -z "$name" ]; then
			register_test "$test_bus_func" "USB $port_index $controller_type"
		else
			register_test "$test_bus_func" "USB $name $controller_type"
		fi

		local devices=()
		local port_num
		port_num="${root_port#usb}"

		while IFS= read -r -d $'\0' dev; do
			local dev_name parent_dev
			dev_name=$(basename "$dev")
			parent_dev=$(readlink -f "$dev/../" | xargs basename 2>/dev/null)

			[[ "$parent_dev" != "$root_port" ]] && continue
			[[ "$dev_name" == "${port_num}-0" ]] && continue
			[[ "$dev_name" == *:* ]] && continue

			devices+=("$dev_name")
		done < <(find /sys/bus/usb/devices -maxdepth 1 -name "${port_num}-*" -print0 2>/dev/null)

		local device_index=0
		for device in "${devices[@]}"; do
			if [ ! -d "/sys/bus/usb/devices/$device" ]; then
				continue
			fi

			if [[ "$device" == *:* ]]; then
				continue
			fi

			if test_usb_register_single_device "$device" 1 "$safe_addr" "$port_index" "$device_index"; then
				((device_index++))
			fi
		done

		((port_index++))
	done
}

ds_rk3568_som_evb_test_usb() {
	local addrs=(
		"fd840000"
		"fcc00000"
		"fd8c0000"
		"fd000000"
	)
	local names=(
		"HOST0 (USB0)"
		"HOST0 (USB0)"
		"HOST1 (USB1)"
		"HOST1 (USB1)"
	)

	local i
	for ((i=0; i<${#addrs[@]}; i++)); do
		test_usb_register_tests "${names[i]}" "${addrs[i]}"
	done
}

ds_rk3568_som_smarc_test_usb() {
	local addrs=(
		"fd840000"
		"fcc00000"
		"fd8c0000"
		"fd000000"
	)
	local names=(
		"HOST0 (USB0)"
		"HOST0 (USB0)"
		"HOST1 (SMARC Internal)"
		"HOST1 (SMARC Internal)"
	)

	local i
	for ((i=0; i<${#addrs[@]}; i++)); do
		test_usb_register_tests "${names[i]}" "${addrs[i]}"
	done

	local expected_devices=(
		"05e3:0610:(USB 2.0 Hub)"
		"05e3:0620:(USB 3.0 Hub)"
	)

	test_usb_register_expected_devices_tests expected_devices
}

ds_rk3588_btb_evb_test_usb() {
	local addrs=(
		"fc000000"
		"fc8c0000"
		"fc880000"
	)
	local names=(
		"USB3.0 OTG0"
		"USB2.0"
		"USB2.0"
	)

	local i
	for ((i=0; i<${#addrs[@]}; i++)); do
		test_usb_register_tests "${names[i]}" "${addrs[i]}"
	done
}

test_usb_default() {
	test_usb_register_tests
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_usb || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!USB_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${USB_DT_MAP[$pattern]}" ]] && ${USB_DT_MAP[$pattern]}
				found_compatible=1
			fi
		done
	done < /proc/device-tree/compatible

	if [ $found_compatible -eq 0 ]; then
		echo "Error: Cannot find suitable devicetree compatible string"
		return 1
	fi
else
	check_dependencies_usb_default || return 1
	USB_DISABLE_TESTS=1
	test_usb_default
fi

return 0
