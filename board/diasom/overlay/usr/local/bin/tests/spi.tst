#!/bin/bash

declare -A SPI_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-imx8m-som-evb"]="ds_imx8m_som_evb_test_spi"
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_spi"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_spi"
)

check_dependencies_spi() {
	local deps=("${DEV_DEPS[@]}")
	local deps=(@dev_modprobe @dev_bind_driver @dev_unbind_driver)
	check_dependencies "SPI" "${deps[@]}"
}

test_spi() {
	local port_num=$1
	local chipselect=$2
	local device="spi${port_num}.${chipselect}"
	local device_path="/sys/bus/spi/devices/${device}"

	if [ ! -e "$device_path" ]; then
		echo "Missing"
		return 1
	fi

	if ! dev_unbind_driver "$device"; then
		echo "Busy"
		return 2
	fi

	local driver="spi-nor"
	dev_modprobe "$driver" "/sys/bus/spi/drivers/$driver" &>/dev/null
	if [[ $? -ne 0 ]]; then
		echo "$driver driver missing"
		return 2
	fi

	if ! dev_bind_driver "$device_path" "$driver"; then
		echo "Missing"
		return 1
	fi

	echo "OK"

	return 0
}

generate_spi_test() {
	local port_num=$1
	local port_name=$2
	local num_chipselects="${3:-1}"

	local cs
	for ((cs=0; cs<num_chipselects; cs++)); do
		local func_name="test_spi${port_num}_cs${cs}"
		local test_name="${port_name} CS#${cs}"
		eval "${func_name}() { test_spi \"${port_num}\" \"${cs}\"; }"

		register_test "${func_name}" "${test_name}"
	done
}

ds_imx8m_som_evb_test_spi() {
	generate_spi_test 1 "SPI1" 1
	generate_spi_test 2 "SPI2" 1
}

ds_rk3568_som_evb_test_spi() {
	generate_spi_test 1 "SPI1" 1
	generate_spi_test 2 "SPI2" 2
}

ds_rk3568_som_smarc_evb_test_spi() {
	generate_spi_test 2 "SPI0" 2
	generate_spi_test 3 "SPI1" 2
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_spi || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!SPI_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${SPI_DT_MAP[$pattern]}" ]] && ${SPI_DT_MAP[$pattern]}
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
