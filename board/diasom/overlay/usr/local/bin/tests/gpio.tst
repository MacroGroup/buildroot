#!/bin/bash

declare -A GPIO_DT_MAP=(
	["diasom,ds-imx8m-som-evb"]="ds_imx8m_som_evb_test_gpio"
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_gpio"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_gpio"
)

check_dependencies_gpio() {
	local deps=()
	check_dependencies "GPIO" "${deps[@]}"
}

test_gpio_get_base() {
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

test_gpio_setup_direction() {
	local gpio="$1"
	local dir="$2"

	local gpio_path="/sys/class/gpio/gpio$gpio"
	if [ -d "$gpio_path" ]; then
		echo -n "$dir" > "$gpio_path/direction"
		echo -n "0" > "$gpio_path/active_low"
 	fi
}

test_gpio_setup() {
	local gpio="$1"

	echo -n "$gpio" > /sys/class/gpio/export 2>/dev/null
	test_gpio_setup_direction "$gpio" "in"
}

test_gpio_getval()
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

test_gpio_setval()
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

test_gpio() {
	local gpio_src="$1"
	local gpio_dst="$2"

	test_gpio_setup "$gpio_src"
	[ -d /sys/class/gpio/gpio"$gpio_src" ] || return 1

	test_gpio_setup "$gpio_dst"
	[ -d /sys/class/gpio/gpio"$gpio_dst" ] || return 1

	test_gpio_setup_direction "$gpio_src" "out"

	local value
	for value in 0 1 ; do
		test_gpio_setval "$gpio_src" "$value" || {
			test_gpio_setup_direction "$gpio_src" "in"
			return 1
		}
		test_gpio_getval "$gpio_dst" "$value" || {
			test_gpio_setup_direction "$gpio_src" "in"
			return 1
		}
	done

	test_gpio_setup_direction "$gpio_src" "in"

	return 0
}

test_gpio_pair() {
	local label1="$1"
	local label2="$3"

	local base1 base2
	base1=$(test_gpio_get_base "$label1") || { echo "$label1 not found"; return 1; }
	base2=$(test_gpio_get_base "$label2") || { echo "$label2 not found"; return 1; }

	local idx1="$2"
	local idx2="$4"

	local nr1=$((base1 + idx1))
	local nr2=$((base2 + idx2))

	test_gpio "$nr1" "$nr2" || {
		echo "$label1:$idx1 -> $label2:$idx2 error"
		return 1
	}

	test_gpio "$nr2" "$nr1" || {
		echo "$label2:$idx2 -> $label1:$idx1 error"
		return 1
	}

	echo "OK"

	return 0
}

test_gpio_unbind_driver() {
	local device="$1"
	local driver="$2"

	echo "$device" | tee "/sys/bus/platform/drivers/$driver/unbind" >/dev/null 2>&1

	if [ ! -e "/sys/bus/platform/drivers/$driver/$device" ]; then
		return 0
	else
		return 1
	fi
}

test_i2s_busy() {
	echo "Busy"

	return 2
}

register_gpio_tests() {
	local gpio_tests=("$@")

	for test_spec in "${gpio_tests[@]}"; do
		read -r label1 idx1 label2 idx2 test_name <<< "$test_spec"

		local func_name="test_gpio_pair_${test_name//-/_}"
		eval "$func_name() { test_gpio_pair \"$label1\" \"$idx1\" \"$label2\" \"$idx2\"; }"
		register_test "$func_name" "$test_name"
	done
}

ds_imx8m_som_evb_test_gpio() {
	local gpio_tests=(
		"gpio5	29	gpio5	28	UART4_TXD-GPIO5.29"
		# TODO
	)

	register_gpio_tests "${gpio_tests[@]}"

	return 0
}

ds_rk3568_som_evb_test_gpio() {
	local gpio_tests=(
		"gpio1	4	gpio1	6	GPIO1-GPIO2"
		"gpio1	7	gpio1	8	GPIO3-GPIO4"
	)

	register_gpio_tests "${gpio_tests[@]}"
}

ds_rk3568_som_smarc_evb_test_gpio() {
	local gpio_tests=(
		"gpio1	2	gpio1	10	GPIO0-GPIO1"
		"gpio3	14	gpio1	11	GPIO2-GPIO3"
		"gpio2	30	gpio3	16	GPIO4-GPIO5"
		"gpio3	15	gpio4	17	GPIO6-GPIO7"
		"2-0023	0	2-0023	1	GPIO8-GPIO9"
		"2-0023	2	2-0023	3	GPIO10-GPIO11"
		"2-0023	4	2-0023	5	GPIO12-GPIO13"
	)

	if test_gpio_unbind_driver "fe410000.i2s" "rockchip-i2s-tdm"; then
		gpio_tests+=(
			"gpio3	23	gpio3	25	I2S1_CK-I2S1_SDOUT"
			"gpio3	24	gpio3	26	I2S1_LRCK-I2S1_SDIN"
		)
	else
		register_test "test_i2s_busy" "I2S0"
	fi

	register_gpio_tests "${gpio_tests[@]}"
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_gpio || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!GPIO_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${GPIO_DT_MAP[$pattern]}" ]] &&  ${GPIO_DT_MAP[$pattern]}
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
