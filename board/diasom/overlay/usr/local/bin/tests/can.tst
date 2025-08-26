#!/bin/bash

declare -A CAN_DT_MAP=(
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_can"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_can"
)

declare -a CAN_INTERFACES

check_dependencies_can() {
	local deps=()
	check_dependencies "CAN" "${deps[@]}"
}

test_can() {
	local iface="$1"

	if [ -d "/sys/class/net/$iface" ]; then
		CAN_INTERFACES+=("$iface")

		echo "OK"

		return 0
	fi

	echo "Missing"

	return 1
}

test_can_loop_can0_can1() {
	echo "Not implemented"

	return 2
}

test_can_can0() {
	test_can can0
}

test_can_can1() {
	test_can can1
	local ret=$?

	if printf '%s\n' "${CAN_INTERFACES[@]}" | grep -q "can0" && printf '%s\n' "${CAN_INTERFACES[@]}" | grep -q "can1"; then
		register_test "@test_can_loop_can0_can1" "CAN Loopback (CAN0-CAN1)"
	fi

	return $ret
}

ds_rk3568_som_evb_test_can() {
	register_test "test_can_can0" "CAN1"
	register_test "test_can_can1" "CAN2"
}

ds_rk3568_som_smarc_evb_test_can() {
	register_test "test_can_can0" "CAN0"
	register_test "test_can_can1" "CAN1"
}

if ! declare -F register_test >/dev/null || ! declare -F check_dependencies >/dev/null || ! declare -F check_devicetree >/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

check_devicetree || return 1

check_dependencies_can || return 1

found_compatible=0
while IFS= read -r -d '' compatible; do
	compat_str=$(echo -n "$compatible" | tr -d '\0')

	for pattern in "${!CAN_DT_MAP[@]}"; do
		if [[ $compat_str == "$pattern" ]]; then
			${CAN_DT_MAP[$pattern]}
			found_compatible=1
		fi
	done
done < /proc/device-tree/compatible

if [ $found_compatible -eq 0 ]; then
	echo "Error: Cannot find suitable devicetree compatible string"
	return 1
fi

return 0
