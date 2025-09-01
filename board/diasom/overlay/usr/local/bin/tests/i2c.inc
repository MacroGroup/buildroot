#!/bin/bash

declare -g I2C_DEPS=(i2cdetect)

i2c_device_test() {
	local bus="$1"
	local addr="$2"

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
		return 1
	fi
}

return 0
