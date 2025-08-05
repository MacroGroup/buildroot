#!/bin/bash

check_dependencies_hdmi() {
	local deps=(modetest)
	check_dependencies "HDMI" "${deps[@]}"
}

test_hdmi_interface() {
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

ds_rk3568_som_smarc_evb_test_hdmi0() {
	test_hdmi_interface "HDMI-A-1"
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
	if check_dependencies_hdmi; then
		if grep -Eq 'diasom,ds-rk3568-som-smarc-evb' /proc/device-tree/compatible; then
			register_test "ds_rk3568_som_smarc_evb_test_hdmi0" "HDMI0"
			return 0
		else
			echo "Error: Cannot find suitable devicetree compatible string"
		fi
	fi
else
	echo "Error: Script cannot be used without devicetree"
fi

return 1
