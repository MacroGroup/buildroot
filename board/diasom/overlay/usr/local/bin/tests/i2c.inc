#!/bin/bash

check_dependencies_i2c() {
	local deps=(i2cdetect)
	check_dependencies "I2C" "${deps[@]}"
}

test_i2c_device() {
	local bus="$1"
	local addr="$2"
	local optional="${3:-0}"

	local output
	output=$(i2cdetect -y "$bus" 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local addr_hex
	local status
	addr_hex=$(printf "%02x" $((addr)))
	status=$(echo "$output" | awk -v addr="$addr_hex" '
		BEGIN { found=0 }
		{
			if ($0 ~ /^[0-9a-f]{2}:/) {
				split($0, parts, " ")

				for (i = 2; i <= length(parts); i++) {
					if (parts[i] == addr || parts[i] == "UU") {
						found = 1
						status = parts[i]
						exit 0
					}
				}
			}
		}
		END {
			if (found) print status
			else print "not_found"
		}
	')

	if [ "$status" == "UU" ]; then
		echo "OK"
		return 0
	elif [ "$status" == "$addr_hex" ]; then
		echo "OK"
		return 0
	else
		echo "Missing"
		if [ "$optional" -eq 1 ]; then
			return 2
		else
			return 1
		fi
	fi
}

check_i2c_bus() {
	local bus="$1"

	if [ ! -e "/dev/i2c-$bus" ]; then
		echo "Missing"
		return 1
	fi

	echo "OK"

	return 0
}

test_i2c2_0x23() {
	test_i2c_device 2 0x23
}

test_i2c2_0x70() {
	test_i2c_device 2 0x70
	local ret=$?

	if [ $ret -eq 0 ]; then
		register_test "@ds_rk3568_som_smarc_evb_test_i2c8" "    I2C8 Bus (I2C_LCD)"
		register_test "@ds_rk3568_som_smarc_evb_test_i2c7" "    I2C7 Bus (I2C_CAM1)"
		register_test "@ds_rk3568_som_smarc_evb_test_i2c6" "    I2C6 Bus (I2C_CAM0)"
	fi

	return $ret
}

test_i2c3_0x50() {
	test_i2c_device 3 0x50
}

test_i2c3_0x51() {
	test_i2c_device 3 0x51
}

test_i2c3_0x68() {
	test_i2c_device 3 0x68
}

ds_rk3568_som_smarc_evb_test_i2c2() {
	local indent="  "

	if [ -e /dev/i2c-2 ]; then
		register_test "@test_i2c2_0x70" "${indent}I2C2 Device 0x70 (I2C MUX)"
		register_test "@test_i2c2_0x23" "${indent}I2C2 Device 0x23 (I2C GPIO)"

		echo "OK"

		return 0
	fi

	echo "Missing"

	return 1
}

ds_rk3568_som_smarc_evb_test_i2c3() {
	local indent="  "

	if [ -e /dev/i2c-3 ]; then
		register_test "@test_i2c3_0x68" "${indent}I2C3 Device 0x68 (RTC)"
		register_test "@test_i2c3_0x51" "${indent}I2C3 Device 0x51 (EEPROM)"
		register_test "@test_i2c3_0x50" "${indent}I2C3 Device 0x50 (EEPROM)"

		echo "OK"

		return 0
	fi

	echo "Missing"

	return 1
}

ds_rk3568_som_smarc_evb_test_i2c4() {
	check_i2c_bus 4
}

ds_rk3568_som_smarc_evb_test_i2c6() {
	check_i2c_bus 6
}

ds_rk3568_som_smarc_evb_test_i2c7() {
	check_i2c_bus 7
}

ds_rk3568_som_smarc_evb_test_i2c8() {
	check_i2c_bus 8
}

if ! declare -F register_test >/dev/null || ! declare -F check_dependencies >/dev/null || ! declare -F check_devicetree >/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

check_devicetree || return 1

check_dependencies_i2c || return 1

if grep -Eq 'diasom,ds-rk3568-som-smarc-evb' /proc/device-tree/compatible; then
	register_test "ds_rk3568_som_smarc_evb_test_i2c2" "I2C2 Bus (Internal)"
	register_test "ds_rk3568_som_smarc_evb_test_i2c3" "I2C3 Bus (I2C_GP)"
	register_test "ds_rk3568_som_smarc_evb_test_i2c4" "I2C4 Bus (I2C_PM)"

	return 0
else
	echo "Error: Cannot find suitable devicetree compatible string"
fi

return 1
