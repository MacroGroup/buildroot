#!/bin/bash
# shellcheck disable=SC2181

declare -A PCI_DT_MAP=(
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_pci"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_pci"
)

readonly PCIE_MIN_SPEED=100

check_dependencies_pci() {
	local deps=("${WLAN_DEPS[@]}")
	deps+=(@test_speed_wlan)
	deps+=(dd fio hexdump jq lspci nvme sed timeout)
	check_dependencies "PCI" "${deps[@]}"
}

check_dependencies_pci_default() {
	local deps+=(lspci xargs)
	check_dependencies "PCI" "${deps[@]}"
}

test_pci_device() {
	local device="$1"

	local pci_info
	pci_info=$(lspci -n -s "$device" 2>/dev/null)

	if [ -n "$pci_info" ]; then
		local pci_id
		pci_id=$(echo "$pci_info" | awk '{print $3}')
		if [ -n "$pci_id" ]; then
			echo "$pci_id"
		else
			echo "OK"
		fi

		return 0
	fi

	echo "Missing"

	return 1
}

test_pci_get_nvme_device() {
	local device="$1"
	local nvme_ctrl nvme_dev
	nvme_ctrl=$(grep -l "$device" /sys/class/nvme/*/address | cut -d/ -f5)

	if [ -z "$nvme_ctrl" ]; then
		echo "NVMe: Missing"
		return 2
	fi

	nvme_dev="/dev/${nvme_ctrl}n1"
	if [ ! -b "$nvme_dev" ]; then
		nvme_dev=$(find /dev -name "${nvme_ctrl}n*" -type b 2>/dev/null | head -n1)

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

test_pci_get_speed() {
	local device="$1"
	local writetest="$2"

	local pcie_info line speed width version speed_val width_val
	pcie_info=$(lspci -vv -s "$device" 2>/dev/null | grep -E 'LnkSta:|LnkCap:')
	speed=""
	width=""
	version=""

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
		speed_val=$(echo "$speed" | sed 's/GT\/s//')
		width_val="${width//x/}"

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
	local nvme_dev
	nvme_dev=$(test_pci_get_nvme_device "$device")
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$nvme_dev"
		return $ret
	fi

	local read_output
	read_output=$(fio --name=read_test --filename="$nvme_dev" --rw=read \
		--bs=128k --iodepth=64 --runtime=2 --time_based --direct=1 \
		--ioengine=libaio --output-format=json 2>&1)
	if [ $? -ne 0 ]; then
		echo "NVMe: Error"
		return 1
	fi

	local read_speed min_read_speed
	read_speed=$(echo "$read_output" | jq -r '.jobs[0].read.bw' 2>/dev/null)

	if [[ ! "$read_speed" =~ ^[0-9.]+$ ]]; then
		echo "NVMe: Error"
		return 1
	fi

	read_speed=$(echo "scale=2; $read_speed / 1024" | bc)

	min_read_speed=$(test_pci_get_speed "$device" false)

	echo "NVMe: ${read_speed} MB/s"

	if (( $(echo "$read_speed > $min_read_speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_pci_write_speed_nvme() {
	local device="$1"
	local nvme_dev
	nvme_dev=$(test_pci_get_nvme_device "$device")
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$nvme_dev"
		return $ret
	fi

	local write_output
	write_output=$(fio --name=write_test --filename="$nvme_dev" --rw=write \
		--bs=128k --iodepth=64 --runtime=2 --time_based --direct=1 \
		--ioengine=libaio --output-format=json 2>&1)
	if [ $? -ne 0 ]; then
		echo "NVMe: Error"
		return 1
	fi

	local write_speed min_write_speed
	write_speed=$(echo "$write_output" | jq -r '.jobs[0].write.bw' 2>/dev/null)

	if [[ ! "$write_speed" =~ ^[0-9.]+$ ]]; then
		echo "NVMe: Error"
		return 1
	fi

	write_speed=$(echo "scale=2; $write_speed / 1024" | bc)

	min_write_speed=$(test_pci_get_speed "$device" true)

	echo "NVMe: ${write_speed} MB/s"
	if (( $(echo "$write_speed > $min_write_speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_pci_speed_wlan() {
	local device="$1"
	local writetest="$2"

	local min_speed
	min_speed=$(test_pci_get_speed "$device" "$writetest")

	test_speed_wlan "$device" "$min_speed" "$writetest"
}

test_pci_read_speed_unknown() {
	local device="$1"
	local class="$2"

	echo "Unsupported class: $class"

	return 2
}

test_pci_write_speed_unknown() {
	local device="$1"
	local class="$2"

	echo "Unsupported class: $class"

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

	local class=${class_info:0:2}

	case "$class" in
	"01")
		if [ "${class_info:2:2}" = "08" ]; then
			test_pci_read_speed_nvme "$device"
		else
			test_pci_read_speed_unknown "$device" "$class_info"
		fi
		;;
	"02")
		test_pci_speed_wlan "$device" false
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

	local class=${class_info:0:2}

	case "$class" in
	"01")
		if [ "${class_info:2:2}" = "08" ]; then
			test_pci_write_speed_nvme "$device"
		else
			test_pci_write_speed_unknown "$device" "$class_info"
		fi
		;;
	"02")
		test_pci_speed_wlan "$device" true
		;;
	*)
		test_pci_write_speed_unknown "$device" "$class_info"
		;;
	esac
}

test_pci_find_device() {
	local value="$1"

	find /sys/devices/platform -name "*.pcie" -type d -print0 2>/dev/null | while IFS= read -r -d $'\0' platform_dir; do
		node_dir="$platform_dir/of_node"

		[[ -f "$node_dir/reg" ]] || continue

		local file_size region_size num_regions
		file_size=$(stat -c %s "$node_dir/reg" 2>/dev/null)
		[[ -z "$file_size" ]] && continue

		region_size=8
		num_regions=$((file_size / region_size))

		local i
		for ((i=0; i<num_regions; i++)); do
			local offset=$((i * region_size))

			local addr_bytes
			addr_bytes=$(dd if="$node_dir/reg" bs=1 skip=$((offset + 4)) count=4 2>/dev/null | hexdump -v -e '/1 "%02x"')

			while [[ ${#addr_bytes} -lt 8 ]]; do
				addr_bytes="0$addr_bytes"
			done

			if [[ "$addr_bytes" == "$value" ]]; then
				local pci_dir device
				pci_dir=$(find "$platform_dir" -maxdepth 1 -type d -name 'pci*' -print -quit)
				[[ -z "$pci_dir" ]] && continue

				device=$(
					find "$pci_dir" -maxdepth 1 -type d -name '????:??:??.?' 2>/dev/null | while IFS= read -r path; do
						local name
						name=$(basename "$path")
						if echo "$name" | grep -Eq '^[0-9]{4}:[0-9]{2}:[0-9]{2}\.[0-9]$'; then
							echo "$name"
							break
						fi
					done | head -n1
				)

				if [[ -n "$device" ]]; then
					echo "$device"
					return
				fi
			fi
		done
	done

	echo -n ""
}

test_pci_register_tests() {
	local name="$1"
	local addr="$2"

	local root_port
	root_port=$(test_pci_find_device "$addr")
	[[ -z "$root_port" ]] && return

	local safe_addr="${addr//[^[:alnum:]]/_}"

	local test_bus_func="test_pci_bus_$safe_addr"
	eval "$test_bus_func() { test_pci_device \"$root_port\"; }"
	register_test "$test_bus_func" "PCI Bus $name"

	local device=""
	for dev in /sys/bus/pci/devices/"$root_port"/*; do
		if [[ -d "$dev" ]]; then
			local dev_name
			dev_name=$(basename "$dev")
			if [[ "$dev_name" == "$root_port" ]]; then
				continue
			fi

			if [[ "$dev_name" =~ ^[0-9]{4}:[0-9]{2}:[0-9]{2}\.[0-9]$ ]]; then
				device="$dev_name"
				break
			fi
		fi
	done

	local test_dev_func="test_pci_device_$safe_addr"
	if [[ -n "$device" ]]; then
		eval "$test_dev_func() { test_pci_device \"$device\"; }"
	else
		eval "$test_dev_func() { echo \"Missing\"; return 1; }"
	fi
	register_test "$test_dev_func" "PCI Device $name" 1

	if [[ -n "$device" ]]; then
		local test_read_func="test_pci_read_speed_$safe_addr"
		eval "$test_read_func() { test_pci_read_speed \"$device\"; }"
		register_test "$test_read_func" "PCI Device $name Read" 1

		local test_write_func="test_pci_write_speed_$safe_addr"
		eval "$test_write_func() { test_pci_write_speed \"$device\"; }"
		register_test "$test_write_func" "PCI Device $name Write" 1
	fi
}

ds_rk3568_som_evb_test_pci() {
	local addrs=(
		"fe260000"
		"fe280000"
	)
	local names=(
		"2x1"
		"3x2"
	)

	local i
	for ((i=0; i<${#addrs[@]}; i++)); do
		test_pci_register_tests "${names[i]}" "${addrs[i]}"
	done
}

ds_rk3568_som_smarc_evb_test_pci() {
	local addrs=(
		"fe280000"
		"fe270000"
		"fe260000"
	)
	local names=(
		"3x2 (PCIE_A)"
		"3x1 (PCIE_B)"
		"2x1 (PCIE_C)"
	)

	local i
	for ((i=0; i<${#addrs[@]}; i++)); do
		test_pci_register_tests "${names[i]}" "${addrs[i]}"
	done
}

test_pci_default() {
	while IFS= read -r device_path; do
		local device
		device=$(basename "$device_path")

		if [[ ! "$device" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
			continue
		fi

		if [ ! -d "$device_path" ]; then
			continue
		fi

		local has_children=false
		local children=()

		for child_path in "$device_path"/*; do
			local child_name
			child_name=$(basename "$child_path")
			if [[ -d "$child_path" && "$child_name" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
				has_children=true
				children+=("$child_name")
			fi
		done

		if $has_children; then
			local safe_device="${device//[^[:alnum:]]/_}"
			local test_func="test_pci_device_$safe_device"
			eval "$test_func() { test_pci_device \"$device\"; }"
			register_test "$test_func" "PCI Root Port $device"

			for child_device in "${children[@]}"; do
				local safe_child_device="${child_device//[^[:alnum:]]/_}"
				local child_test_func="test_pci_device_$safe_child_device"
				eval "$child_test_func() { test_pci_device \"$child_device\"; }"
				register_test "$child_test_func" "PCI Device $child_device" 1
			done
		fi
	done < <(find /sys/bus/pci/devices -maxdepth 1 -name "????:??:??.?")
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_pci || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!PCI_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${PCI_DT_MAP[$pattern]}" ]] && ${PCI_DT_MAP[$pattern]}
				found_compatible=1
			fi
		done
	done < /proc/device-tree/compatible

	if [ $found_compatible -eq 0 ]; then
		echo "Error: Cannot find suitable devicetree compatible string"
		return 1
	fi
else
	check_dependencies_pci_default || return 1
	test_pci_default
fi

return 0
