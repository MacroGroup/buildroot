#!/bin/bash
# shellcheck disable=SC2329,SC2181

declare -A ETH_DT_MAP=(
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_eth"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_eth"
)

declare -a ETH_INTERFACES

check_dependencies_eth() {
	local deps=(ethtool ip iperf)
	check_dependencies "ETH" "${deps[@]}"
}

check_dependencies_eth_default() {
	local deps=(ip)
	check_dependencies "ETH" "${deps[@]}"
}

test_eth_get_speed() {
	local iface="$1"
	local speed

	speed=$(ethtool "$iface" 2>/dev/null | \
	grep -A 100 'Supported link modes' | \
		grep -oE '[0-9]+base' | \
		sed 's/base//' | \
		sort -nr | \
		head -n 1)

	if [[ "$speed" =~ ^[0-9]+$ ]] && [[ $speed -gt 0 ]]; then
		echo "$speed"

		return 0
	fi

	echo "0"

	return 1
}

test_eth_cable_connection() {
	local iface="$1"
	local carrier_file="/sys/class/net/$iface/carrier"

	if [ -f "$carrier_file" ]; then
		local carrier
		carrier=$(cat "$carrier_file" 2>/dev/null)

		if [ "$carrier" = "1" ]; then
			return 0
		else
			return 1
		fi
	fi

	return 1
}

test_eth_speed() {
	local SERVER_IFACE="$1"
	local CLIENT_IFACE="$2"
	local speed0 speed1 max_speed
	speed0=$(test_eth_get_speed "$SERVER_IFACE")
	speed1=$(test_eth_get_speed "$CLIENT_IFACE")
	max_speed=$((speed0 > speed1 ? speed0 : speed1))

	ETH_SERVER_IFACE="$SERVER_IFACE"
	ETH_CLIENT_IFACE="$CLIENT_IFACE"

	cleanup() {
		kill "${IPERF_PID:-}" 2>/dev/null

		local server_iface="$ETH_SERVER_IFACE"
		local client_iface="$ETH_CLIENT_IFACE"

		if ip netns exec ns_server ip link show "$server_iface" &>/dev/null; then
			ip netns exec ns_server ip link set "$server_iface" netns 1
		fi

		if ip netns exec ns_client ip link show "$client_iface" &>/dev/null; then
			ip netns exec ns_client ip link set "$client_iface" netns 1
		fi

		sleep 0.5

		ip link set dev "$server_iface" up 2>/dev/null
		ip link set dev "$client_iface" up 2>/dev/null

		ip netns del --wait 5 ns_server 2>/dev/null
		ip netns del --wait 5 ns_client 2>/dev/null

		sleep 4.5

		if [ -n "$ETH_CONSOLE_LEVEL" ] && [ -w /proc/sys/kernel/printk ]; then
			echo "$ETH_CONSOLE_LEVEL" > /proc/sys/kernel/printk 2>/dev/null
		fi
	}
	trap cleanup EXIT RETURN INT TERM HUP

	if [ -r /proc/sys/kernel/printk ]; then
		ETH_CONSOLE_LEVEL=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
		echo 1 > /proc/sys/kernel/printk 2>/dev/null
	fi

	ip netns del ns_server 2>/dev/null
	ip netns del ns_client 2>/dev/null
	sleep 0.1

	ip netns add ns_server || {
		echo "Error 1" >&2
		return 1
	}
	ip netns add ns_client || {
		echo "Error 2" >&2
		return 1
	}

	ip link set "$SERVER_IFACE" netns ns_server || {
		echo "Error 3" >&2
		return 1
	}

	ip link set "$CLIENT_IFACE" netns ns_client || {
		echo "Error 4" >&2
		return 1
	}

	ip netns exec ns_server ip addr add 192.168.1.198/24 dev "$SERVER_IFACE" || {
		echo "Error 5" >&2
		return 1
	}

	ip netns exec ns_client ip addr add 192.168.1.197/24 dev "$CLIENT_IFACE" || {
		echo "Error 6" >&2
		return 1
	}

	ip netns exec ns_server ip link set dev "$SERVER_IFACE" up || {
		echo "Error 7" >&2
		return 1
	}

	ip netns exec ns_client ip link set dev "$CLIENT_IFACE" up || {
		echo "Error 8" >&2
		return 1
	}

	ip netns exec ns_server iperf -s -B 192.168.1.198 >/dev/null 2>&1 &
	IPERF_PID=$!
	sleep 0.1

	kill -0 $IPERF_PID 2>/dev/null || {
		echo "Error 9" >&2
		return 1
	}

	local output
	output=$(ip netns exec ns_client iperf -c 192.168.1.198 -B 192.168.1.197 -t 2 -y C 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "Error 10" >&2
		return 1
	fi

	local bandwidth
	bandwidth=$(echo "$output" | awk -F',' '
	END {
		if (NF == 9) bits_per_second = $9;
		else if (NF >= 15) bits_per_second = $(NF-1);
		else exit 1;
		printf "%.2f", bits_per_second / 1000000
	}')

	if [ -z "$bandwidth" ]; then
		echo "Error 11" >&2
		return 1
	fi

	echo "${bandwidth} Mbps"

	if (( $(echo "$bandwidth < $max_speed * 0.9" | bc -l) )); then
		return 2
	fi

	return 0
}

test_eth() {
	local iface="$1"

	if ip link show dev "$iface" >/dev/null 2>&1; then
		if ! test_eth_cable_connection "$iface"; then
			echo "Unplugged"
			return 2
		fi

		ETH_INTERFACES+=("$iface")

		echo "OK"

		return 0
	fi

	echo "Missing"

	return 1
}

test_eth_loop_end0_end1() {
	test_eth_speed "end0" "end1"
}

test_eth_end0() {
	test_eth "end0"
}

test_eth_end1_with_loop() {
	test_eth "end1"
	local ret=$?

	if printf '%s\n' "${ETH_INTERFACES[@]}" | grep -q "end0" && printf '%s\n' "${ETH_INTERFACES[@]}" | grep -q "end1"; then
		register_test "@test_eth_loop_end0_end1" "Eth0-Eth1 Bandwidth"
	fi

	return $ret
}

ds_rk3568_som_evb_test_eth()
{
	register_test "test_eth_end0" "Ethernet 0 (GMAC0)"
	register_test "test_eth_end1_with_loop" "Ethernet 1 (GMAC1)"
}

ds_rk3568_som_smarc_evb_test_eth()
{
	register_test "test_eth_end0" "Ethernet 0 (GBE0)"
	register_test "test_eth_end1_with_loop" "Ethernet 1 (GBE1)"
}

test_eth_default() {
	local all_interfaces=()
	local interface
	while IFS= read -r -d '' interface; do
		all_interfaces+=("$(basename "$interface")")
	done < <(find /sys/class/net -mindepth 1 -maxdepth 1 -type l -print0 2>/dev/null)

	local eth_interfaces=()
	for interface in "${all_interfaces[@]}"; do
		local interface_type
		interface_type=$(cat "/sys/class/net/$interface/type" 2>/dev/null)

		if [[ "$interface_type" != "1" ]]; then
			continue
		fi

		eth_interfaces+=("$interface")
	done

	for interface in "${eth_interfaces[@]}"; do
		local test_func="test_eth_${interface}"
		eval "${test_func}() { test_eth \"${interface}\"; }"
		register_test "${test_func}" "Ethernet ${interface}"
	done
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_eth || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!ETH_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${ETH_DT_MAP[$pattern]}" ]] && ${ETH_DT_MAP[$pattern]}
				found_compatible=1
			fi
		done
	done < /proc/device-tree/compatible

	if [ $found_compatible -eq 0 ]; then
		echo "Error: Cannot find suitable devicetree compatible string"
		return 1
	fi
else
	check_dependencies_eth_default || return 1
	test_eth_default
fi

return 0
