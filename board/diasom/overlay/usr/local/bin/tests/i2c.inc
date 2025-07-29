#!/bin/bash

check_dependencies_i2c() {
	for i in i2cdetect; do
		if ! command -v "$i" &>/dev/null; then
			echo "Error: $i not installed"
			return 1
		fi
	done

	return 0
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

	local addr_hex=$(printf "%02x" $((addr)))
	local status
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
	if [ -e /dev/i2c-2 ]; then
		if [ "$1" = "register" ]; then
			register_test "test_i2c2_0x23" "I2C2 Device 0x23"
			register_test "test_i2c2_0x70" "I2C2 Device 0x70"
		fi
		echo "OK"
		return 0
	else
		echo "Missing"
		return 1
	fi
}

ds_rk3568_som_smarc_evb_test_i2c3() {
	if [ -e /dev/i2c-3 ]; then
		if [ "$1" = "register" ]; then
			register_test "test_i2c3_0x50" "I2C3 Device 0x50"
			register_test "test_i2c3_0x51" "I2C3 Device 0x51"
			register_test "test_i2c3_0x68" "I2C3 Device 0x68"
		fi
		echo "OK"
		return 0
	else
		echo "Missing"
		return 1
	fi
}

ds_rk3568_som_smarc_evb_test_i2c4() {
	if [ "$1" = "register" ]; then
		return 0
	fi

	check_i2c_bus 4
}

ds_rk3568_som_smarc_evb_test_i2c6() {
	if [ "$1" = "register" ]; then
		return 0
	fi

	check_i2c_bus 6
}

ds_rk3568_som_smarc_evb_test_i2c7() {
	if [ "$1" = "register" ]; then
		return 0
	fi

	check_i2c_bus 7
}

ds_rk3568_som_smarc_evb_test_i2c8() {
	if [ "$1" = "register" ]; then
		return 0
	fi

	check_i2c_bus 8
}

if [ -f /proc/device-tree/compatible ]; then
	if check_dependencies_i2c; then
		if grep -Eq 'diasom,ds-rk3568-som-smarc-evb' /proc/device-tree/compatible; then
			register_test "ds_rk3568_som_smarc_evb_test_i2c2" "I2C2 Bus"
			register_test "ds_rk3568_som_smarc_evb_test_i2c3" "I2C3 Bus"
			register_test "ds_rk3568_som_smarc_evb_test_i2c4" "I2C4 Bus"
			register_test "ds_rk3568_som_smarc_evb_test_i2c6" "I2C6 Bus"
			register_test "ds_rk3568_som_smarc_evb_test_i2c7" "I2C7 Bus"
			register_test "ds_rk3568_som_smarc_evb_test_i2c8" "I2C8 Bus"
			return 0
		else
			echo "Error: Cannot find suitable devicetree compatible string"
		fi
        fi
else
	echo "Error: Script cannot be used without devicetree"
fi

return 1
