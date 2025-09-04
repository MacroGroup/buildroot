#!/bin/bash

declare -g DEV_DEPS=()

dev_unbind_drivers() {
	local device="$1"
	local driver="$2"

	echo "$device" | tee "/sys/bus/platform/drivers/$driver/unbind" >/dev/null 2>&1

	if [ -e "/sys/bus/platform/drivers/$driver/$device" ]; then
		return 1
	fi

	return 0
}

return 0
