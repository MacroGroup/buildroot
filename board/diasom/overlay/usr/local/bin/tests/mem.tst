#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

check_dependencies_ram() {
	local deps=(fio jq)
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

	if (( $(echo "$memtotal_mb > 500" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_ram_read_speed() {
	local test_file="/dev/shm/ramtest.$$"
	local output

	output=$(fio --name=read_test --filename="$test_file" --rw=read \
		--bs=1M --size=1G --runtime=2 --time_based --ioengine=sync \
		--output-format=json 2>/dev/null)

	local ret=$?

	rm -f "$test_file"

	if [ $ret -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local bw
	bw=$(echo "$output" | jq -r '.jobs[0].read.bw' 2>/dev/null)
	if [[ ! "$bw" =~ ^[0-9.]+$ ]]; then
		echo "Error"
		return 1
	fi

	local bw_mb
	bw_mb=$(echo "scale=2; $bw / 1024" | bc)

	echo "${bw_mb} MB/s"

	if (( $(echo "$bw_mb < 100" | bc -l) )); then
		return 1
	elif (( $(echo "$bw_mb <= 1000" | bc -l) )); then
		return 2
	else
		return 0
	fi
}

test_ram_write_speed() {
	local test_file="/dev/shm/ramtest.$$"
	local output

	output=$(fio --name=write_test --filename="$test_file" --rw=write \
		--bs=1M --size=1G --runtime=2 --time_based --ioengine=sync \
		--output-format=json 2>/dev/null)

	local ret=$?

	rm -f "$test_file"

	if [ $ret -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local bw
	bw=$(echo "$output" | jq -r '.jobs[0].write.bw' 2>/dev/null)
	if [[ ! "$bw" =~ ^[0-9.]+$ ]]; then
		echo "Error"
		return 1
	fi

	local bw_mb
	bw_mb=$(echo "scale=2; $bw / 1024" | bc)

	echo "${bw_mb} MB/s"

	if (( $(echo "$bw_mb < 100" | bc -l) )); then
		return 1
	elif (( $(echo "$bw_mb <= 800" | bc -l) )); then
		return 2
	else
		return 0
	fi
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

register_test "test_ram" "RAM Capacity"
register_test "test_ram_read_speed" "RAM Read"
register_test "test_ram_write_speed" "RAM Write"

return 0
