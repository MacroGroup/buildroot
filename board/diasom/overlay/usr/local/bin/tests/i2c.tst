#!/bin/bash

declare -A I2C_DT_MAP=(
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_i2c"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_i2c"
)

check_dependencies_i2c() {
	local deps=("${I2C_DEPS[@]}")
	deps+=(@i2c_device_test)
	check_dependencies "I2C" "${deps[@]}"
}

check_dependencies_i2c_default() {
	local deps=()
	check_dependencies "I2C" "${deps[@]}"
}

generate_i2c_device_test() {
	local bus=$1
	local addr=$2
	local desc=$3
	local level=$4

	local func_name="test_i2c${bus}_${addr}"
	eval "${func_name}() { i2c_device_test ${bus} ${addr}; }"
	register_test "@${func_name}" "I2C${bus} Device ${addr} (${desc})" "${level}"
}

generate_i2c_bus_test() {
	local bus=$1
	local desc=$2
	local level=$3
	local devices=${4:-""}

	local func_name="test_i2c${bus}"
	eval "${func_name}() {
		local bus_path=\"/sys/bus/i2c/devices/i2c-${bus}\"
		if [ ! -d \"\$bus_path\" ]; then
			echo \"Missing\"
			return 1
		fi

		if [ -n \"${devices}\" ]; then
			IFS=',' read -ra dev_list <<< \"${devices}\"
			for device in \"\${dev_list[@]}\"; do
				IFS=':' read -r addr dev_desc <<< \"\$device\"
				generate_i2c_device_test \"${bus}\" \"\$addr\" \"\$dev_desc\" \"$((level + 1))\"
			done
		fi

		echo \"OK\"

		return 0
	}"

	register_test "@${func_name}" "${desc}" "${level}"
}

test_i2c2_0x70() {
	i2c_device_test 2 0x70
	local ret=$?

	if [ $ret -eq 0 ]; then
		generate_i2c_bus_test 8 "I2C8 Bus (I2C_LCD)" 2
		generate_i2c_bus_test 7 "I2C7 Bus (I2C_CAM1)" 2
		generate_i2c_bus_test 6 "I2C6 Bus (I2C_CAM0)" 2
	fi

	return $ret
}

ds_rk3568_som_smarc_evb_test_i2c2() {
	if [ -e /dev/i2c-2 ]; then
		register_test "@test_i2c2_0x70" "I2C2 Device 0x70 (I2C MUX)" 1
		generate_i2c_device_test 2 0x23 "I2C GPIO" 1

		echo "OK"

		return 0
	fi

	echo "Missing"

	return 1
}

ds_rk3568_som_smarc_evb_test_i2c() {
	register_test "ds_rk3568_som_smarc_evb_test_i2c2" "I2C2 Bus (Internal)"
	generate_i2c_bus_test 3 "I2C3 Bus (I2C_GP)" 0 "0x68:RTC,0x51:EEPROM,0x50:EEPROM"
	generate_i2c_bus_test 4 "I2C4 Bus (I2C_PM)" 0
}

ds_rk3568_som_evb_test_i2c() {
	generate_i2c_bus_test 1 "I2C1 Bus" 0 "0x22:FUSB302"
	generate_i2c_bus_test 4 "I2C4 Bus" 0 "0x10:ES8388"
}

test_i2c_default() {
	local i2c_buses=()
	local bus

	while IFS= read -r -d '' bus; do
		local bus_name
		bus_name=$(basename "$bus")
		if [[ "$bus_name" =~ ^i2c-[0-9]+$ ]]; then
			local bus_num=${bus_name#i2c-}
			i2c_buses+=("$bus_num")
		fi
	done < <(find /sys/bus/i2c/devices -name "i2c-*" -type l -print0 2>/dev/null)

	local sorted_buses
	IFS=$'\n' read -r -d '' -a sorted_buses < <(printf '%s\n' "${i2c_buses[@]}" | sort -nr && printf '\0')
	unset IFS

	for bus_num in "${sorted_buses[@]}"; do
		generate_i2c_bus_test "$bus_num" "I2C${bus_num} Bus" 0
	 done
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_i2c || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!I2C_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${I2C_DT_MAP[$pattern]}" ]] && ${I2C_DT_MAP[$pattern]}
				found_compatible=1
			fi
		done
	done < /proc/device-tree/compatible

	if [ $found_compatible -eq 0 ]; then
		echo "Error: Cannot find suitable devicetree compatible string"
		return 1
	fi
else
	check_dependencies_i2c_default || return 1
	test_i2c_default
fi

return 0
