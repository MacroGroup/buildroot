#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

check_dependencies_ram() {
	local deps=()
	check_dependencies "RAM" "${deps[@]}"
}

test_ram() {
	local memtotal_kb
	memtotal_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
	if [ -z "$memtotal_kb" ]; then
		echo "Error"
		return 1
	fi

	local memtotal_mb=$((memtotal_kb / 1024))
	if [ $memtotal_mb -ge 1024 ]; then
		local memtotal_gb
		memtotal_gb=$(echo "scale=2; $memtotal_mb / 1024" | bc)
		echo "${memtotal_gb} GB"
	else
		echo "${memtotal_mb} MB"
	fi

	return 0
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

register_test "@test_ram" "RAM Capacity"

return 0
