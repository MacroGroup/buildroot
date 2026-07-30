#!/usr/bin/env bash
# shellcheck disable=SC2034
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -g PWM_DEPS=()

pwm_find_chip_by_reg() {
	local target_reg="$1"

	local platform_dir="/sys/devices/platform/${target_reg}.pwm"
	if [ ! -d "$platform_dir" ]; then
		return 1
	fi

	local pwm_link="${platform_dir}/pwm"
	if [ -d "$pwm_link" ]; then
		for chip in "$pwm_link"/pwmchip*; do
			if [ -d "$chip" ]; then
				local chip_name
				chip_name=$(basename "$chip")
				if [[ "$chip_name" =~ ^pwmchip([0-9]+)$ ]]; then
					echo "${BASH_REMATCH[1]}"
					return 0
				fi
			fi
		done
	fi

	return 1
}

pwm_export_channel() {
	local chip="$1"
	local channel="$2"
	local chip_path="/sys/class/pwm/pwmchip${chip}"

	[ -d "$chip_path" ] || { echo "PWM: Not Found"; return 1; }

	local pwm_path="${chip_path}/pwm${channel}"
	if [ ! -d "$pwm_path" ]; then
		echo "$channel" > "${chip_path}/export" 2>/dev/null || {
			echo "PWM: Error"
			return 1
		}
		sleep 0.1
	fi

	[ -d "$pwm_path" ] || { echo "PWM: Error"; return 1; }

	echo "$pwm_path"

	return 0
}

pwm_enable() {
	local pwm_path="$1"
	local pwm_status="$2"

	if [ -z "$pwm_path" ] || [ ! -f "${pwm_path}/enable" ]; then
		echo "PWM: Not Found"
		return 1
	fi

	echo "$pwm_status" > "${pwm_path}/enable" 2>/dev/null || {
		echo "PWM: Error"
		return 1
	}

	return 0
}

pwm_setup() {
	local reg="$1"
	local channel="$2"
	local freq_hz="$3"
	local duty_percent="$4"

	if [ -z "$reg" ] || [ -z "$channel" ] || [ -z "$freq_hz" ] || [ -z "$duty_percent" ]; then
		echo "PWM: Invalid value"
		return 1
	fi

	if [ "$duty_percent" -lt 0 ] || [ "$duty_percent" -gt 100 ]; then
		echo "PWM: Invalid value"
		return 1
	fi

	local chip
	chip=$(pwm_find_chip_by_reg "$reg") || {
		echo "PWM: Not Found"
		return 1
	}

	local pwm_path
	pwm_path=$(pwm_export_channel "$chip" "$channel") || return 1

	pwm_enable "${pwm_path}" "0" || return 1

	local period_ns=$((1000000000 / freq_hz))
	if [ "$period_ns" -eq 0 ]; then
		echo "PWM: Invalid value"
		return 1
	fi

	echo "$period_ns" > "${pwm_path}/period" 2>/dev/null || {
		echo "PWM: Invalid value"
		return 1
	}

	local duty_ns=$((period_ns * duty_percent / 100))
	echo "$duty_ns" > "${pwm_path}/duty_cycle" 2>/dev/null || {
		echo "PWM: Invalid value"
		return 1
	}

	pwm_enable "${pwm_path}" "1" || return 1

	echo "$pwm_path"

	return 0
}

return 0
