#!/bin/bash

check_dependencies_hdmi() {
	local deps=(modetest)
	check_dependencies "HDMI" "${deps[@]}"
}

test_hdmi() {
	local interface="$1"

	if [ -d "/sys/class/drm/card0-$interface" ]; then
		echo "OK"
		return 0
	fi

	if modetest -c | grep -q "$interface"; then
		echo "OK"
		return 0
	fi

	echo "Missing"

	return 1
}

test_hdmi0() {
	test_hdmi "HDMI-A-1"
}

if ! declare -F register_test >/dev/null || ! declare -F check_dependencies >/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ ! -f /proc/device-tree/compatible ]; then
	echo "Error: Script cannot be used without devicetree"

	return 1
fi

check_dependencies_hdmi || return 1

if grep -Eq 'diasom,ds-rk3568-som-smarc-evb' /proc/device-tree/compatible; then
	register_test "test_hdmi0" "HDMI0"

	return 0
else
	echo "Error: Cannot find suitable devicetree compatible string"
fi

return 1
