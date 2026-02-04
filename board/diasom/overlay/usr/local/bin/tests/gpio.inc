#!/usr/bin/env bash
# shellcheck disable=SC2034
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -g GPIO_DEPS=()

gpio_get_base() {
	local expected="$1"

	local chip
	for chip in /sys/class/gpio/gpiochip*; do
		[ -e "$chip" ] || continue

		local label
		label=$(cat "$chip/label")
		if [ "$label" != "$expected" ]; then
			continue
		fi

		local base
		base=$(cat "$chip/base")

		echo -n "$base"

		return 0
	done

	return 1
}

gpio_setup_direction() {
	local gpio="$1"
	local dir="$2"

	local gpio_path="/sys/class/gpio/gpio$gpio"
	if [ -d "$gpio_path" ]; then
		echo -n "$dir" > "$gpio_path/direction"
		echo -n "0" > "$gpio_path/active_low"
 	fi
}

gpio_setup() {
	local gpio="$1"

	echo -n "$gpio" > /sys/class/gpio/export 2>/dev/null
	gpio_setup_direction "$gpio" "in"
}

gpio_getval()
{
	local gpio="$1"
	local value="$2"

	local val
	val=$(cat /sys/class/gpio/gpio"$gpio"/value)
	if [ "$val" -ne "$value" ]; then
		return 1
	fi

	return 0
}

gpio_setval()
{
	local gpio="$1"
	local value="$2"

	echo -n "$value" > /sys/class/gpio/gpio"$gpio"/value

	local val
	val=$(cat /sys/class/gpio/gpio"$gpio"/value)
	if [ "$val" -ne "$value" ]; then
		return 1
	fi

	return 0
}

return 0
