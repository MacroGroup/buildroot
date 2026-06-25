#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2181
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -g VER_DEPS=(
	"${I2C_DEPS[@]}"
	"${IIO_DEPS[@]}"
	@gpio_get_base @gpio_setup
	@i2c_device_test
	@iio_get_value
)

declare -gx SOM_VERSION=0
declare -gx EVB_VERSION=0
declare -gx MOD_VERSION=0

ver_get_ds_rk3568_som_version() {
	i2c_device_test 0 0x1c &>/dev/null
	if [ $? -eq 0 ]; then
		SOM_VERSION=0x200
		echo "Ver. 2+"
	else
		SOM_VERSION=0x100
		echo "Ver. 1"
	fi

	return 0
}

ver_get_ds_rk3568_som_evb_version() {
	i2c_device_test 4 0x70 &>/dev/null
	if [ $? -eq 0 ]; then
		EVB_VERSION=0x130
		echo "Ver. 1.3.0+"
	else
		i2c_device_test 4 0x50 >/dev/null
		if [ $? -eq 0 ]; then
			EVB_VERSION=0x121
			echo "Ver. 1.2.1+"
		else
			EVB_VERSION=0x110
			echo "Ver. 1.1.0+"
		fi
	fi

	return 0
}

ver_get_ds_rk3568_som_smarc_version() {
	i2c_device_test 3 0x68 &>/dev/null
	if [ $? -eq 0 ]; then
		MOD_VERSION=0x111
		echo "Ver. 1.1.1"
	else
		MOD_VERSION=0x300
		echo "Ver. 3"
	fi

	return 0
}

ver_get_ds_rk3568_som_sodimm_version() {
	local voltage
	voltage=$(iio_get_value "fe720000.saradc" 1)

	if [ $? -ne 0 ]; then
		echo "$voltage"
		return 1
	fi

	if [ "$voltage" -lt 100 ]; then
		MOD_VERSION=0x111
		echo "Ver. 1.1.1"
		return 0
	fi

	echo "Unhandled value ($voltage mV)"

	return 2
}

ver_get_ds_rk3588_btb_version() {
	local voltage
	voltage=$(iio_get_value "fec10000.adc" 7)

	if [ $? -ne 0 ]; then
		echo "$voltage"
		return 1
	fi

	if [[ "$voltage" -gt 250 && "$voltage" -lt 350 ]]; then
		SOM_VERSION=0x003
		echo "Ver. 3"
		return 0
	fi

	echo "Unhandled value ($voltage mV)"

	return 2
}

ver_get_ds_rk3588_btb_evb_version() {
	i2c_device_test 7 0x22 &>/dev/null
	if [ $? -ne 0 ]; then
		echo "Unknown variant"
		return 2
	fi

	local base
	base=$(gpio_get_base "7-0022") || { echo "GPIO expander not found"; return 1; }

	local nr val
	nr=$((base + 0))
	gpio_setup "$nr"
	val=$(cat /sys/class/gpio/gpio"$nr"/value)
	nr=$((base + 1))
	gpio_setup "$nr"
	(( val += $(cat /sys/class/gpio/gpio"$nr"/value) * 2 ))
	nr=$((base + 2))
	gpio_setup "$nr"
	(( val += $(cat /sys/class/gpio/gpio"$nr"/value) * 4 ))
	nr=$((base + 3))
	gpio_setup "$nr"
	(( val += $(cat /sys/class/gpio/gpio"$nr"/value) * 8 ))

	if [[ $val -eq 0 ]]; then
		EVB_VERSION=0x002
		echo "Ver. 2"
		return 0
	fi

	echo "Unhandled value ($val)"

	return 2
}

return 0
