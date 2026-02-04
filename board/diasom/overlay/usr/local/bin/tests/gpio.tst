#!/usr/bin/env bash
# shellcheck disable=SC2181,SC2309
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -A GPIO_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-imx8m-som-evb"]="ds_imx8m_som_evb_test_gpio"
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_gpio"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_gpio"
	["diasom,ds-rk3588-btb"]=""
)

check_dependencies_gpio() {
	local deps=("${DEV_DEPS[@]}" "${GPIO_DEPS[@]}" "${I2C_DEPS[@]}")
	deps+=(@dev_unbind_driver)
	deps+=(@gpio_get_base @gpio_setup_direction @gpio_setup @gpio_getval @gpio_setval)
	deps+=(@i2c_device_test @ver_get_ds_rk3568_som_evb_version)
	check_dependencies "GPIO" "${deps[@]}"
}

test_gpio() {
	local gpio_src="$1"
	local gpio_dst="$2"

	gpio_setup "$gpio_src"
	[ -d /sys/class/gpio/gpio"$gpio_src" ] || return 1

	gpio_setup "$gpio_dst"
	[ -d /sys/class/gpio/gpio"$gpio_dst" ] || return 1

	gpio_setup_direction "$gpio_src" "out"

	local value
	for value in 0 1 ; do
		gpio_setval "$gpio_src" "$value" || {
			gpio_setup_direction "$gpio_src" "in"
			return 1
		}
		gpio_getval "$gpio_dst" "$value" || {
			gpio_setup_direction "$gpio_src" "in"
			return 1
		}
	done

	gpio_setup_direction "$gpio_src" "in"

	return 0
}

test_gpio_pair() {
	local label1="$1"
	local label2="$3"
	local oneway="$5"

	local base1 base2
	base1=$(gpio_get_base "$label1") || { echo "$label1 not found"; return 1; }
	base2=$(gpio_get_base "$label2") || { echo "$label2 not found"; return 1; }

	local idx1="$2"
	local idx2="$4"

	local nr1=$((base1 + idx1))
	local nr2=$((base2 + idx2))

	test_gpio "$nr1" "$nr2" || {
		echo "$label1:$idx1 -> $label2:$idx2 error"
		return 1
	}

	if [ -z "$oneway" ] || [ "$oneway" = "0" ]; then
		test_gpio "$nr2" "$nr1" || {
			echo "$label2:$idx2 -> $label1:$idx1 error"
			return 1
		}
	fi

	echo "OK"

	return 0
}

test_gpio_busy() {
	echo "Busy"

	return 2
}

register_gpio_pair_tests() {
	local gpio_tests=("$@")

	local test_spec
	for test_spec in "${gpio_tests[@]}"; do
		read -r label1 idx1 label2 idx2 test_name oneway <<< "$test_spec"

		local func_name="test_gpio_pair_${test_name//-/_}"
		if [ -n "$oneway" ]; then
			eval "$func_name() { test_gpio_pair \"$label1\" \"$idx1\" \"$label2\" \"$idx2\" \"$oneway\"; }"
		else
			eval "$func_name() { test_gpio_pair \"$label1\" \"$idx1\" \"$label2\" \"$idx2\"; }"
		fi
		register_test "$func_name" "$test_name"
	done
}

ds_imx8m_som_evb_test_gpio() {
	local gpio_tests=(
		"gpio5	29	gpio5	28	UART4_TXD-UART4_RXD"
		# TODO
	)

	register_gpio_pair_tests "${gpio_tests[@]}"

	return 0
}

ds_rk3568_som_evb_test_gpio() {
	ver_get_ds_rk3568_som_evb_version &>/dev/null
	if [[ "$EVB_VERSION" -ge 0x121 ]]; then
		local gpio_tests=(
			"gpio1	4	gpio1	6	GPIO0-GPIO1	1"
			"gpio1	7	gpio1	8	GPIO2-GPIO3	1"
		)

		register_gpio_pair_tests "${gpio_tests[@]}"
	else
		local gpio_tests=(
			"gpio1	4	gpio1	6	GPIO0-GPIO1"
			"gpio1	7	gpio1	8	GPIO2-GPIO3"
		)

		register_gpio_pair_tests "${gpio_tests[@]}"
	fi
}

ds_rk3568_som_smarc_evb_test_gpio() {
	local gpio_tests=(
		"gpio1	2	gpio3	14	GPIO0-GPIO2"
		"gpio2	30	gpio3	16	GPIO4-GPIO5"
		"gpio3	15	gpio4	17	GPIO6-GPIO7"
	)

	i2c_device_test 2 0x23 &>/dev/null
	if [ $? -eq 0 ]; then
		gpio_tests+=(
			"2-0023	0	2-0023	1	GPIO8-GPIO9"
			"2-0023	2	2-0023	3	GPIO10-GPIO11"
			"2-0023	4	2-0023	5	GPIO12-GPIO13"
		)
	fi

	if dev_unbind_driver "fe410000.i2s"; then
		gpio_tests+=(
			"gpio3	23	gpio3	25	I2S1_CK-I2S1_SDOUT"
			"gpio3	24	gpio3	26	I2S1_LRCK-I2S1_SDIN"
		)
	else
		register_test "test_gpio_busy" "I2S0"
	fi

	register_gpio_pair_tests "${gpio_tests[@]}"
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
