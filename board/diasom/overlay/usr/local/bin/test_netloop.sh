#!/bin/sh

for i in awk ip iperf usleep; do
	if ! command -v "$i" >/dev/null 2>&1; then
		echo "Script cannot be executed due missing \"$i\" tool!" >&2
		exit 1
	fi
done

if [ $# -ne 2 ]; then
	echo "Usage: $0 <SERVER_INTERFACE> <CLIENT_INTERFACE>" >&2
	exit 1
fi

SERVER_IFACE=$1
CLIENT_IFACE=$2

cleanup() {
	{ kill "$IPERF_PID" 2>&1; } >/dev/null
	{ ip netns del ns_server 2>&1; } >/dev/null
	{ ip netns del ns_client 2>&1; } >/dev/null

	usleep 5000000

	if [ -n "$OLD_CONSOLE_LEVEL" ] && [ -w /proc/sys/kernel/printk ]; then
		echo "$OLD_CONSOLE_LEVEL" > /proc/sys/kernel/printk 2>/dev/null
	fi
}
trap cleanup EXIT INT TERM

if [ -r /proc/sys/kernel/printk ]; then
	OLD_CONSOLE_LEVEL=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
	echo 1 > /proc/sys/kernel/printk 2>/dev/null
fi

{ ip link show "$SERVER_IFACE" >/dev/null 2>&1; } || {
	echo "Network interface $SERVER_IFACE does not exist!" >&2
	exit 1
}
{ ip link show "$CLIENT_IFACE" >/dev/null 2>&1; } || {
	echo "Network interface $CLIENT_IFACE does not exist!" >&2
	exit 1
}

{ ip netns add ns_server 2>&1; } >/dev/null || exit 1
{ ip netns add ns_client 2>&1; } >/dev/null || exit 1

{ ip link set "$SERVER_IFACE" netns ns_server 2>&1; } >/dev/null || {
	echo "Failed to move $SERVER_IFACE to network namespace" >&2
	exit 1
}
{ ip link set "$CLIENT_IFACE" netns ns_client 2>&1; } >/dev/null || {
	echo "Failed to move $CLIENT_IFACE to network namespace" >&2
	exit 1
}

{ ip netns exec ns_server ip addr add 192.168.1.198/24 dev "$SERVER_IFACE" 2>&1; } >/dev/null || {
	echo "Failed to add IP address to $SERVER_IFACE" >&2
	exit 1
}
{ ip netns exec ns_client ip addr add 192.168.1.197/24 dev "$CLIENT_IFACE" 2>&1; } >/dev/null || {
	echo "Failed to add IP address to $CLIENT_IFACE" >&2
	exit 1
}

{ ip netns exec ns_server ip link set dev "$SERVER_IFACE" up 2>&1; } >/dev/null || {
	echo "Failed to bring up $SERVER_IFACE" >&2
	exit 1
}
{ ip netns exec ns_client ip link set dev "$CLIENT_IFACE" up 2>&1; } >/dev/null || {
	echo "Failed to bring up $CLIENT_IFACE" >&2
	exit 1
}

{ ip netns exec ns_server iperf -s -B 192.168.1.198 2>&1; } >/dev/null &
IPERF_PID=$!

usleep 500000

{ kill -0 $IPERF_PID 2>&1; } >/dev/null || {
	echo "iperf server failed to start" >&2
	exit 1
}

OUTPUT=$({ ip netns exec ns_client iperf -c 192.168.1.198 -B 192.168.1.197 -t 10 -y C 2>&1; })

if [ $? -ne 0 ]; then
	echo "iperf client failed" >&2
	exit 1
fi

BANDWIDTH=$(echo "$OUTPUT" | awk -F',' '
END {
	if (NF == 9) {
		bits_per_second = $9
	} else if (NF >= 15) {
		bits_per_second = $(NF-1)
	} else {
		print "ERROR: Unknown iperf output format" > "/dev/stderr"
		exit 1
	}
	printf "%.2f", bits_per_second / 1000000
}')

if [ -z "$BANDWIDTH" ]; then
	echo "Failed to parse iperf output" >&2
	echo "Raw iperf output:" >&2
	echo "$OUTPUT" >&2
	exit 1
fi

echo "Bandwidth: $BANDWIDTH Mbit/s"

exit 0
