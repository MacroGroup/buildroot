#!/bin/bash

declare -g DEV_DEPS=(modprobe)

dev_modprobe() {
	local module="$1"
	local check="$2"

	if [ ! -e "$check" ]; then
		if modprobe "$module" &>/dev/null; then
			sleep 0.5
		fi
	fi

	if [ ! -e "$check" ]; then
		return 1
	fi

	return 0
}

dev_unbind_driver() {
	local device="$1"
	local driver="$2"

	echo "$device" | tee "/sys/bus/platform/drivers/$driver/unbind" >/dev/null 2>&1

	if [ -e "/sys/bus/platform/drivers/$driver/$device" ]; then
		return 1
	fi

	return 0
}

return 0
