#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -g WLAN_DEPS=(iw iperf3 ip jq timeout)

wlan_speed_test() {
	local iface="$1"
	local min_speed="$2"
	local writetest="$3"

	if [ -z "$iface" ]; then
		echo "WLAN: Interface not found (Unsupported card?)"
		return 2
	fi

	local wireless_path="/sys/class/net/$iface/wireless"
	if [ ! -d "$wireless_path" ]; then
		echo "WLAN: Not a wireless interface"
		return 2
	fi

	local mon_iface="mon$RANDOM"

	if ! iw phy "$(cat "/sys/class/net/$iface/phy80211/name")" interface add "$mon_iface" type monitor 2>/dev/null; then
		echo "WLAN: Cannot create monitor interface"
		return 2
	fi

	ip link set "$mon_iface" up
	sleep 0.5
	iperf3 -s -B 127.0.0.1 -p 5201 >/dev/null 2>&1 &
	local server_pid=$!
	sleep 0.5

	local iperf_args=(-c 127.0.0.1 -t 1 -i 0 -u -b 0 --json)
	if [ "$writetest" = true ]; then
		iperf_args+=(-R)
	fi

	local output
	output=$(timeout 5 iperf3 "${iperf_args[@]}" 2>/dev/null)
	kill $server_pid 2>/dev/null
	wait $server_pid 2>/dev/null

	sleep 0.5
	if ip link show "$mon_iface" &>/dev/null; then
		ip link set "$mon_iface" down 2>/dev/null
		sleep 0.1
		ip link del "$mon_iface" 2>/dev/null
	fi

	if [ -z "$output" ]; then
		echo "WLAN: Error"
		return 1
	fi

	local speed_bps speed_mbs json_field
	if [ "$writetest" = true ]; then
		json_field=".end.sum_received.bits_per_second"
	else
		json_field=".end.sum_sent.bits_per_second"
	fi

	speed_bps=$(echo "$output" | jq -r "$json_field")
	if [[ ! "$speed_bps" =~ ^[0-9.]+$ ]]; then
		echo "WLAN: Error"
		return 1
	fi

	speed_mbs=$(echo "scale=2; $speed_bps / 8 / 1024 / 1024" | bc)

	echo "WLAN: ${speed_mbs} MB/s"

	if (( $(echo "$speed_mbs >= $min_speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

return 0
