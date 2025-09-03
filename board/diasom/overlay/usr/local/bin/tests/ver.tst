#!/bin/bash
# shellcheck disable=SC2034,SC2181

declare -A VER_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-rk3568-som"]="ds_rk3568_som_test_version"
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_version"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_version"
)

declare -gx SOM_VERSION=0
declare -gx EVB_VERSION=0
declare -gx SMARC_VERSION=0

check_dependencies_ver() {
	local deps=("${I2C_DEPS[@]}" "${IIO_DEPS[@]}")
	deps+=(@i2c_device_test @iio_get_value)
	check_dependencies "VER" "${deps[@]}"
}

ds_rk3568_get_som_version() {
	if i2c_device_test 0 0x1c >/dev/null; then
		SOM_VERSION=0x200
		echo "Ver. 2+"
	else
		SOM_VERSION=0x100
		echo "Ver. 1"
	fi

	return 0
}

ds_rk3568_get_som_evb_version() {
	if i2c_device_test 4 0x70 >/dev/null; then
		EVB_VERSION=0x130
		echo "Ver. 1.3.0+"
	else
		if i2c_device_test 4 0x50 >/dev/null; then
			EVB_VERSION=0x121
			echo "Ver. 1.2.1+"
		else
			EVB_VERSION=0x120
			echo "Ver. 1.2.0"
		fi
	fi

	return 0
}

ds_rk3568_get_som_smarc_evb_version() {
	local voltage
	voltage=$(iio_get_value "fe720000.saradc" 1)

	if [ $? -ne 0 ]; then
		echo "$voltage"
		return 1
	fi

	if [ "$voltage" -lt 100 ]; then
		SMARC_VERSION=0x111
		echo "Ver. 1.1.1"
		return 0
	fi

	echo "Unhandled value ($voltage mV)"

	return 2
}

ds_rk3568_som_test_version() {
	register_test "@@ds_rk3568_get_som_version" "SOM Version"
}

ds_rk3568_som_evb_test_version() {
	register_test "@@ds_rk3568_get_som_evb_version" "EVB Version"
}

ds_rk3568_som_smarc_evb_test_version() {
	register_test "@@ds_rk3568_get_som_smarc_evb_version" "SMARC Version"
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_ver || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!VER_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${VER_DT_MAP[$pattern]}" ]] && ${VER_DT_MAP[$pattern]}
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
