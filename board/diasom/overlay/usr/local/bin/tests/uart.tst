#!/bin/bash
# shellcheck disable=SC2329

declare -A UART_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_uart"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_uart"
)

check_dependencies_uart() {
	local deps=(lsof socat stty)
	check_dependencies "UART" "${deps[@]}"
}

test_uart() {
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

generate_uart_test() {
	local port_suff=$1
	local port_name=$2
	local baud_rate="${3:-115200}"

	local func_name="test_uart${port_suff}"
	eval "${func_name}() { test_uart \"/dev/tty${port_suff}\" \"${baud_rate}\"; }"
	register_test "${func_name}" "${port_name}"
}

ds_rk3568_som_evb_test_uart() {
	generate_uart_test "S3" "UART3"
	generate_uart_test "S7" "UART7"
	generate_uart_test "S8" "UART8"
	generate_uart_test "S9" "UART9"
}

ds_rk3568_som_smarc_evb_test_uart() {
	generate_uart_test "S4" "UART4 (SER0)"
	generate_uart_test "S8" "UART8 (SER2)"
	generate_uart_test "S5" "UART5 (SER3)"
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
