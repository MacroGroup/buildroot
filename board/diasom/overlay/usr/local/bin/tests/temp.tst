#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -A TEMP_DT_MAP=(
	["diasom,ds-imx8m-som"]="imx8m_test_temp"
	["diasom,ds-rk3568-som"]="rk3568_test_temp"
	["diasom,ds-rk3588-btb"]="rk3588_test_temp"
)

check_dependencies_temp() {
	local deps=()
	check_dependencies "TEMP" "${deps[@]}"
}

test_temp_zone() {
	local zone="$1"
	local zone_path="/sys/class/thermal/$zone"

	if [ ! -d "$zone_path" ]; then
		echo "Missing"
		return 1
	fi

	local temp_file="$zone_path/temp"

	if [ ! -f "$temp_file" ]; then
		echo "Error"
		return 1
	fi

	local temp
	temp=$(cat "$temp_file" 2>/dev/null)

	if [ -z "$temp" ] || [ "$temp" -eq 0 ]; then
		echo "Invalid data"
		return 1
	fi

	local temp_c
	temp_c=$(echo "scale=1; $temp / 1000" | bc)

	echo "$temp_c" | awk '{printf "%.1f°C\n", $1}'

	if (( $(echo "$temp_c > 75" | bc -l) )); then
		return 2
	elif (( $(echo "$temp_c < 10" | bc -l) )); then
		return 2
	fi

	return 0
}

find_thermal_zone_by_type() {
	local target_type="$1"
	local zones=(/sys/class/thermal/thermal_zone*)

	for zone_path in "${zones[@]}"; do
		local type_file="$zone_path/type"
		if [ -f "$type_file" ]; then
			local zone_type
			zone_type=$(cat "$type_file" 2>/dev/null)
			if [ "$zone_type" = "$target_type" ]; then
				basename "$zone_path"
				return 0
			fi
		fi
	done

	return 1
}

generate_temp_test() {
	local zone="$1"
	local test_name="$2"

	local func_name="test_temp_${zone}"
	eval "${func_name}() { test_temp_zone \"${zone}\"; }"
	register_test "${func_name}" "${test_name}"
}

generate_temp_test_type() {
	local zone_type="$1"
	local test_name="$2"
	local zone

	if zone=$(find_thermal_zone_by_type "$zone_type"); then
		generate_temp_test "$zone" "Temperature $test_name"
	else
		local func_name="test_temp_missing_${test_name// /_}"
		eval "${func_name}() { echo \"Missing\"; return 1; }"
		register_test "${func_name}" "Temperature ${test_name}"
	fi
}

imx8m_test_temp() {
	generate_temp_test_type "cpu-thermal" "CPU"
}

rk3568_test_temp() {
	generate_temp_test_type "cpu-thermal" "CPU"
	generate_temp_test_type "gpu-thermal" "GPU"
}

rk3588_test_temp() {
	generate_temp_test_type "package-thermal" "SoC"
	generate_temp_test_type "center-thermal" "CPU"
	generate_temp_test_type "gpu-thermal" "GPU"
	generate_temp_test_type "npu-thermal" "NPU"
}

test_temp_default() {
	local zones=(/sys/class/thermal/thermal_zone*)

	if [ ${#zones[@]} -eq 0 ]; then
		return
	fi

	for zone_path in "${zones[@]}"; do
		local zone
		zone=$(basename "$zone_path")
		local type_file="$zone_path/type"

		if [ ! -f "$type_file" ]; then
			continue
		fi

		local zone_type
		zone_type=$(cat "$type_file" 2>/dev/null)

		generate_temp_test "$zone" "Temperature ${zone_type}"
	done
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_temp || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!TEMP_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${TEMP_DT_MAP[$pattern]}" ]] && ${TEMP_DT_MAP[$pattern]}
				found_compatible=1
			fi
		done
	done < /proc/device-tree/compatible

	if [ $found_compatible -eq 0 ]; then
		echo "Error: Cannot find suitable devicetree compatible string"
		return 1
	fi
else
	test_temp_default
fi

return 0
