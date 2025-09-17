#!/usr/bin/env bash
# shellcheck disable=SC2181,SC2034
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -g I2C_DEPS=(i2cdetect)

i2c_device_test() {
	local bus="$1"
	local addr="$2"

	local output
	output=$(i2cdetect -y "$bus" "$addr" "$addr" 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local addr_hex
	addr_hex=$(printf "%02x" $((addr)))

	if echo "$output" | grep -qE " ($addr_hex|UU)"; then
		echo "OK"
		return 0
	fi

	echo "Missing"

	return 1
}

return 0
