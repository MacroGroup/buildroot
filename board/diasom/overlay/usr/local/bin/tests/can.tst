#!/usr/bin/env bash

declare -A CAN_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_can"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_can"
)

declare -a CAN_INTERFACES

check_dependencies_can() {
	local deps=(cansend ifconfig ip)
	check_dependencies "CAN" "${deps[@]}"
}

test_can_generate_msg() {
	local test_id=$(( RANDOM % 1792 + 256 ))
	printf -v test_id "%03X" $test_id

	local data_length=$(( RANDOM % 8 + 1 ))
	local test_data=""
	local i byte hex_byte

	for ((i=0; i<data_length; i++)); do
		byte=$(( RANDOM % 256 ))
		printf -v hex_byte "%02X" $byte
		test_data="${test_data}${hex_byte}"
	done

	echo "$test_id#$test_data"
}

test_can() {
	local iface="$1"

	if [ ! -d "/sys/class/net/$iface" ]; then
		echo "Missing"
		return 1
	fi

	cleanup() {
		if [ -n "$CAN_CONSOLE_LEVEL" ] && [ -w /proc/sys/kernel/printk ]; then
			echo "$CAN_CONSOLE_LEVEL" > /proc/sys/kernel/printk 2>/dev/null
		fi
	}
	trap cleanup EXIT RETURN INT TERM HUP

	if [ -r /proc/sys/kernel/printk ]; then
		CAN_CONSOLE_LEVEL=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
		echo 1 > /proc/sys/kernel/printk 2>/dev/null
	fi

	ip link set "$iface" down &>/dev/null
	ip link set dev "$iface" up type can bitrate 125000 &>/dev/null

	sleep 0.5

	local msg
	msg=$(test_can_generate_msg)
	cansend "$iface" "$msg"

	sleep 0.5

	if ifconfig "$iface" 2>/dev/null | grep -q "UP" && ifconfig "$iface" 2>/dev/null | grep -q "RUNNING"; then
		CAN_INTERFACES+=("$iface")
		echo "OK"
		return 0
	fi

	echo "BUS-OFF"

	return 1
}

test_can_loop() {
	local iface1="$1"
	local iface2="$2"

	echo "Not implemented"

	return 2
}

test_can_loop_can0_can1() {
	test_can_loop can0 can1
}

test_can_can0() {
	test_can can0
}

test_can_can1_with_loop() {
	test_can can1
	local ret=$?

	if printf '%s\n' "${CAN_INTERFACES[@]}" | grep -q "can0" && printf '%s\n' "${CAN_INTERFACES[@]}" | grep -q "can1"; then
		register_test "@test_can_loop_can0_can1" "CAN Loopback (CAN0-CAN1)"
	fi

	return $ret
}

ds_rk3568_som_evb_test_can() {
	register_test "test_can_can0" "CAN1"
	register_test "test_can_can1_with_loop" "CAN2"
}

ds_rk3568_som_smarc_evb_test_can() {
	register_test "test_can_can0" "CAN0 (CAN0)"
	register_test "test_can_can1_with_loop" "CAN2 (CAN1)"
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_can || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!CAN_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${CAN_DT_MAP[$pattern]}" ]] && ${CAN_DT_MAP[$pattern]}
				found_compatible=1
			fi
		done
	done < /proc/device-tree/compatible

	if [ $found_compatible -eq 0 ]; then
		echo "Error: Cannot find suitable devicetree compatible string"
		return 1
	fi
fi

return 0
