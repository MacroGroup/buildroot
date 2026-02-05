#!/usr/bin/env bash
# shellcheck disable=SC2329
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -A UART_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_uart"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_uart"
	["diasom,ds-rk3588-btb"]=""
)

check_dependencies_uart() {
	local deps=(lsof socat)
	deps+=(@gpio_get_base @gpio_setup @gpio_setup_direction @gpio_setval)
	check_dependencies "UART" "${deps[@]}"
}

test_uart_self() {
	local device="$1"
	local baud_rate="$2"

	if [ ! -c "$device" ]; then
		echo "Missing"
		return 1
	fi

	if lsof -t "$device" >/dev/null 2>&1; then
		echo "Busy"
		return 1
	fi

	local data
	data=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $((8 + RANDOM % 5)))

	cleanup() {
		[ -n "$pipe" ] && rm -f "$pipe" 2>/dev/null
		[ -n "$socat_pid" ] && kill -INT "$socat_pid" 2>/dev/null

		if [ -n "$UART_CONSOLE_LEVEL" ] && [ -w /proc/sys/kernel/printk ]; then
			echo "$UART_CONSOLE_LEVEL" > /proc/sys/kernel/printk 2>/dev/null
		fi
	}
	trap cleanup EXIT RETURN INT TERM HUP

	if [ -r /proc/sys/kernel/printk ]; then
		UART_CONSOLE_LEVEL=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
		echo 1 > /proc/sys/kernel/printk 2>/dev/null
	fi

	local pipe
	pipe=$(mktemp -u) || return 1
	if ! mkfifo "$pipe"; then
		echo "Error"
		return 1
	fi

	socat -u "OPEN:$device,b$baud_rate,raw,echo=0" "PIPE:$pipe" 2>/dev/null &
	local socat_pid=$!

	sleep 0.8

	if ! echo -n "$data" > "$device" 2>/dev/null; then
		echo "$baud_rate Failed"
		return 1
	fi

	local received_data
	received_data=$(timeout 2 cat "$pipe")

	kill -INT "$socat_pid" 2>/dev/null
	wait "$socat_pid" 2>/dev/null
	rm -f "$pipe" 2>/dev/null

	if [[ "$data" == "$received_data" ]]; then
		echo "$baud_rate OK"
		return 0
	fi

	echo "$baud_rate Failed"

	return 1
}

generate_uart_test_self() {
	local port_suff=$1
	local port_name=$2
	local baud_rate="${3:-115200}"

	local func_name="test_uart_self${port_suff}"
	eval "${func_name}() { test_uart_self \"/dev/tty${port_suff}\" \"${baud_rate}\"; }"
	register_test "${func_name}" "${port_name}"
}

test_uart_cross_oneway() {
	local tx_port="$1"
	local rx_port="$2"
	local tx_gpio="$3"
	local rx_gpio="$4"
	local baud_rate="${5:-115200}"

	if [ ! -c "$tx_port" ] || [ ! -c "$rx_port" ]; then
		echo "Missing"
		return 1
	fi

	if lsof -t "$tx_port" >/dev/null 2>&1 || lsof -t "$rx_port" >/dev/null 2>&1; then
		echo "Busy"
		return 1
	fi

	gpio_setup "$tx_gpio"
	gpio_setup_direction "$tx_gpio" "out"

	gpio_setup "$rx_gpio"
	gpio_setup_direction "$rx_gpio" "out"

	gpio_setval "$tx_gpio" 1
	gpio_setval "$rx_gpio" 0

	local data
	data=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $((8 + RANDOM % 5)))

	cleanup() {
		[ -n "$pipe" ] && rm -f "$pipe" 2>/dev/null
		[ -n "$socat_pid" ] && kill -INT "$socat_pid" 2>/dev/null
		gpio_setup_direction "$tx_gpio" "in"
		gpio_setup_direction "$rx_gpio" "in"
		if [ -n "$UART_CONSOLE_LEVEL" ] && [ -w /proc/sys/kernel/printk ]; then
			echo "$UART_CONSOLE_LEVEL" > /proc/sys/kernel/printk 2>/dev/null
		fi
	}
	trap cleanup EXIT RETURN INT TERM HUP

	if [ -r /proc/sys/kernel/printk ]; then
		UART_CONSOLE_LEVEL=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
		echo 1 > /proc/sys/kernel/printk 2>/dev/null
	fi

	local pipe
	pipe=$(mktemp -u) || return 3
	if ! mkfifo "$pipe"; then
		echo "Error"
		return 1
	fi

	socat -u "OPEN:$rx_port,b$baud_rate,raw,echo=0" "PIPE:$pipe" 2>/dev/null &
	socat_pid=$!

	sleep 0.8

	if ! echo -n "$data" > "$tx_port" 2>/dev/null; then
		echo "$baud_rate Failed"
		return 1
	fi

	sleep 0.5

	local received_data
	received_data=$(timeout 1 cat "$pipe" 2>/dev/null || true)

	kill -INT "$socat_pid" 2>/dev/null
	wait "$socat_pid" 2>/dev/null
	rm -f "$pipe" 2>/dev/null

	if [[ "$data" == "$received_data" ]]; then
		echo "$baud_rate OK"
		return 0
	fi

	echo "$baud_rate Failed"

	return 1
}

generate_uart_cross_test() {
	local port1="$1"
	local port2="$2"
	local gpio1="$3"
	local gpio2="$4"
	local baud_rate="${5:-115200}"
	local test_name="$6"

	local safe_test_name="${test_name//[ ><-]/_}"
	local func_name="test_uart_cross_${safe_test_name}"
	eval "${func_name}() { test_uart_cross_oneway \"/dev/${port1}\" \"/dev/${port2}\" \"$gpio1\" \"$gpio2\" \"$baud_rate\"; }"
	register_test "${func_name}" "${test_name}"
}

generate_uart_cross_pair() {
	local port1="$1"
	local port2="$2"
	local label1="$3"
	local label2="$4"
	local gpio_idx1="$5"
	local gpio_idx2="$6"
	local test_base_name="$7"
	local baud_rate="${8:-115200}"

	local base1 base2
	base1=$(gpio_get_base "$label1") || { echo "$label1 not found"; return 1; }
	base2=$(gpio_get_base "$label2") || { echo "$label2 not found"; return 1; }

	local nr1=$((base1 + gpio_idx1))
	local nr2=$((base2 + gpio_idx2))

	generate_uart_cross_test \
		"$port1" "$port2" \
		"$nr1" "$nr2" \
		"$baud_rate" \
		"${test_base_name} TX->RX"

	generate_uart_cross_test \
		"$port2" "$port1" \
		"$nr2" "$nr1" \
		"$baud_rate" \
		"${test_base_name} RX<-TX"
}

ds_rk3568_som_evb_test_uart() {
	generate_uart_test_self "S3" "UART3"
	generate_uart_test_self "S7" "UART7"
	generate_uart_test_self "S8" "UART8"
	generate_uart_test_self "S9" "UART9"
}

ds_rk3568_som_smarc_evb_test_uart() {
	generate_uart_test_self "S4" "UART4 (SER0)"
	generate_uart_test_self "S8" "UART8 (SER2)"
	generate_uart_test_self "S5" "UART5 (SER3)"
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_uart || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!UART_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${UART_DT_MAP[$pattern]}" ]] && ${UART_DT_MAP[$pattern]}
				found_compatible=1
			fi
		done
	done < /proc/device-tree/compatible

	if [ $found_compatible -eq 0 ]; then
		echo "Error: Cannot find suitable devicetree compatible string"
		return 1
	fi
fi

return 0
