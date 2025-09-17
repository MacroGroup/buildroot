#!/usr/bin/env bash
# shellcheck disable=SC2034
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -g IIO_DEPS=()

iio_get_value() {
	local iio_name="$1"
	local channel="$2"

	local iio_dev_path
	iio_dev_path=$(find /sys/bus/iio/devices -name "iio:device*" -exec grep -l "$iio_name" {}/name \; 2>/dev/null | head -1)
	if [ -z "$iio_dev_path" ]; then
		echo "Error: $iio_name not found"
		return 1
	fi

	iio_dev_path=$(dirname "$iio_dev_path")
	local raw_file="${iio_dev_path}/in_voltage${channel}_raw"
	local scale_file="${iio_dev_path}/in_voltage_scale"

	if [ ! -f "$raw_file" ] || [ ! -f "$scale_file" ]; then
		echo "Error: Channel $channel not available"
		return 1
	fi

	local raw scale voltage
	raw=$(cat "$raw_file")
	scale=$(cat "$scale_file")

	voltage=$(echo "scale=4; $raw * $scale" | bc | awk '{printf "%.0f", $1}')

	echo "$voltage"

	return 0
}

return 0
