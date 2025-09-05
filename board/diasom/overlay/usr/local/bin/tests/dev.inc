#!/bin/bash

declare -g DEV_DEPS=(modprobe)

dev_modprobe() {
	local module="$1"
	local check="$2"

	if [ ! -e "$check" ]; then
		if modprobe "$module" &>/dev/null; then
			sleep 0.5
			if [ -e "$check" ]; then
				return 0
			fi
		fi
	else
		return 0
	fi

	return 1
}

dev_unbind_driver() {
	local device="$1"

	local device_path
	while IFS= read -r -d '' device_path; do
		local driver_path
		driver_path=$(dirname "$device_path")

		if echo "$device" > "$driver_path/unbind" 2>/dev/null; then
			sleep 0.1
			if [ -e "$device_path" ]; then
				return 1
			fi
		fi
	done < <(find /sys/bus/*/drivers/ -name "$device" -print0 2>/dev/null)

	return 0
}

return 0
