#!/bin/bash

declare -A HDMI_DT_MAP=(
	["diasom,ds-rk3568-som-evb"]="test_hdmi0"
	["diasom,ds-rk3568-som-smarc-evb"]="test_hdmi0"
)

check_dependencies_hdmi() {
	local deps=(modetest)
	check_dependencies "HDMI" "${deps[@]}"
}

test_hdmi_card() {
	local interface="$1"

	if [ -d "/sys/class/drm/card0-$interface" ]; then
		if modetest -c | grep -q "$interface"; then
			echo "OK"
			return 0
		fi
	fi

	echo "Missing"

	return 1
}

test_hdmi_hdmi0() {
	test_hdmi_card "HDMI-A-1"
}

test_hdmi0() {
	register_test "test_hdmi_hdmi0" "HDMI0"
}

if ! declare -F check_dependencies &>/dev/null || ! declare -F check_devicetree &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

check_devicetree || return 1

check_dependencies_hdmi || return 1

found_compatible=0
while IFS= read -r -d '' compatible; do
	compat_str=$(echo -n "$compatible" | tr -d '\0')

	for pattern in "${!HDMI_DT_MAP[@]}"; do
		if [[ $compat_str == "$pattern" ]]; then
			${HDMI_DT_MAP[$pattern]}
			found_compatible=1
		fi
	done
done < /proc/device-tree/compatible

if [ $found_compatible -eq 0 ]; then
	echo "Error: Cannot find suitable devicetree compatible string"
	return 1
fi

return 0
