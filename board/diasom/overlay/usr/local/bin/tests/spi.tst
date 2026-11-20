#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -A SPI_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_spi"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_spi"
	["diasom,ds-rk3588-btb"]="ds_rk3588_btb_test_spi"
	["diasom,ds-rk3588-btb-evb-hat"]="ds_rk3588_btb_evb_hat_test_spi"
	["diasom,ds-rk3588-smarc"]="ds_rk3588_smarc_test_spi"
	["diasom,ds-rk3588-smarc-evb"]="ds_rk3588_smarc_evb_test_spi"
)

check_dependencies_spi() {
	local deps=("${DEV_DEPS[@]}")
	deps+=(@dev_modprobe @dev_bind_driver @dev_unbind_driver)
	check_dependencies "SPI" "${deps[@]}"
}

test_spi_mtd() {
	local port_num=$1
	local chipselect=$2
	local device="spi${port_num}.${chipselect}"
	local device_path="/sys/bus/spi/devices/${device}"
	local nor_path="${device_path}/spi-nor"
	local driver="spi-nor"

	if [ ! -e "$device_path" ]; then
		echo "Missing"
		return 1
	fi

	local current_driver=""
	if [ -e "${device_path}/driver" ]; then
		local current_path
		current_path=$(readlink -f "${device_path}/driver")
		current_driver=$(basename "$current_path")
	fi

	if [ -n "$current_driver" ] && [ "$current_driver" != "$driver" ]; then
		if ! dev_unbind_driver "$device"; then
			echo "Busy"
			return 2
		fi
		current_driver=""
	fi

	if [ -z "$current_driver" ]; then
		if [ ! -d "/sys/bus/spi/drivers/$driver" ]; then
			dev_modprobe "$driver" "/sys/bus/spi/drivers/$driver" &>/dev/null
		fi
		if [ ! -d "/sys/bus/spi/drivers/$driver" ]; then
			echo "$driver driver missing"
			return 2
		fi

		if ! dev_bind_driver "$device_path" "$driver"; then
			echo "MTD: Missing"
			return 1
		fi

		sleep 0.1
	fi

	local partname="" jedec_id="" manufacturer=""
	[ -s "${nor_path}/partname" ] && partname=$(cat "${nor_path}/partname")
	[ -s "${nor_path}/jedec_id" ] && jedec_id=$(cat "${nor_path}/jedec_id")
	[ -s "${nor_path}/manufacturer" ] && manufacturer=$(cat "${nor_path}/manufacturer")

	local desc=""
	if [ -n "$partname" ]; then
		desc="$partname"
	elif [ -n "$manufacturer" ]; then
		desc="$manufacturer"
	fi
	if [ -n "$jedec_id" ]; then
		if [ -n "$desc" ]; then
			desc="$desc ($jedec_id)"
		else
			desc="$jedec_id"
		fi
	fi

	if [ -z "$desc" ]; then
		echo "MTD: Fail"
		return 1
	fi

	echo "$desc"

	return 0
}

test_spi_presense() {
	local port_num=$1
	local chipselect=$2
	local device="spi${port_num}.${chipselect}"
	local device_path="/sys/bus/spi/devices/${device}"

	if [ ! -e "$device_path" ]; then
		echo "Missing"
		return 1
	fi

	echo "OK"

	return 0
}

generate_spi_mtd_test() {
	local port_num=$1
	local port_name=$2
	local chipselect=$3

	local func_name="test_spi_mtd${port_num}_cs${chipselect}"
	local test_name="${port_name} CS#${chipselect}"
	eval "${func_name}() { test_spi_mtd \"${port_num}\" \"${chipselect}\"; }"

	register_test "${func_name}" "${test_name}"
}

generate_spi_presense_test() {
	local port_num=$1
	local chipselect=$2
	local test_name="$3"

	local func_name="test_spi_presense${port_num}_cs${chipselect}"
	eval "${func_name}() { test_spi_presense \"${port_num}\" \"${chipselect}\"; }"

	register_test "${func_name}" "${test_name}"
}

ds_rk3568_som_evb_test_spi() {
	generate_spi_mtd_test 1 "SPI1" 0
	generate_spi_mtd_test 2 "SPI2" 0
	generate_spi_mtd_test 2 "SPI2" 1
}

ds_rk3568_som_smarc_evb_test_spi() {
	generate_spi_mtd_test 3 "SPI1" 0
	generate_spi_mtd_test 3 "SPI1" 1
}

ds_rk3588_btb_test_spi() {
	generate_spi_presense_test 2 0 "SPI2.0 (RK806)"
}

ds_rk3588_btb_evb_hat_test_spi() {
	generate_spi_mtd_test 0 "SPI0 (HAT)" 0
}

ds_rk3588_smarc_test_spi() {
	generate_spi_mtd_test 5 "QSPI (SPI1)" 0
}

ds_rk3588_smarc_evb_test_spi() {
	generate_spi_mtd_test 3 "SPI3 (SPI0)" 0
	generate_spi_mtd_test 3 "SPI3 (SPI0)" 1
	generate_spi_mtd_test 5 "QSPI (SPI1)" 1
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
