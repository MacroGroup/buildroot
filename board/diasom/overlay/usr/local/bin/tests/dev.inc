#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

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

dev_bind_driver() {
	local device_path="$1"
	local driver="$2"

	cleanup() {
		if [ -n "$DEV_CONSOLE_LEVEL" ] && [ -w /proc/sys/kernel/printk ]; then
			echo "$DEV_CONSOLE_LEVEL" > /proc/sys/kernel/printk 2>/dev/null
		fi
	}
	trap cleanup EXIT RETURN INT TERM HUP

	if [ -r /proc/sys/kernel/printk ]; then
		DEV_CONSOLE_LEVEL=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
		echo 1 > /proc/sys/kernel/printk 2>/dev/null
	fi

	echo "$driver" > "$device_path/driver_override" 2>/dev/null

	local driver_path
	while IFS= read -r -d '' driver_path; do
		local device
		device=$(basename "$device_path")
		echo "$device" > "$driver_path/bind" 2>/dev/null
		sleep 0.1
		if [ -e "$driver_path/$device" ]; then
			return 0
		fi
		break
	done < <(find /sys/bus/*/drivers/ -name "$driver" -print0 2>/dev/null)

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
