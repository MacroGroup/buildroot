#!/bin/bash
# shellcheck disable=SC2034,SC2181

declare -g VER_DEPS=("${I2C_DEPS[@]}" "${IIO_DEPS[@]}" @i2c_device_test @iio_get_value)

declare -gx SOM_VERSION=0
declare -gx EVB_VERSION=0
declare -gx MOD_VERSION=0

ver_get_ds_rk3568_som_version() {
	if i2c_device_test 0 0x1c &>/dev/null; then
		SOM_VERSION=0x200
		echo "Ver. 2+"
	else
		SOM_VERSION=0x100
		echo "Ver. 1"
	fi

	return 0
}

ver_get_ds_rk3568_som_evb_version() {
	if i2c_device_test 4 0x70 &>/dev/null; then
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

ver_get_ds_rk3568_som_smarc_version() {
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

return 0
