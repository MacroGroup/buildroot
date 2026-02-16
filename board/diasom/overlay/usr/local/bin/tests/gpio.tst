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
	local label1_arg="$1"
	local idx1="$2"
	local label2_arg="$3"
	local idx2="$4"
	local oneway="$5"

	local label1="${label1_arg%%:*}"
	local alias1="${label1_arg#*:}"
	[[ "$alias1" == "$label1_arg" ]] && alias1="$label1"
	local label2="${label2_arg%%:*}"
	local alias2="${label2_arg#*:}"
	[[ "$alias2" == "$label2_arg" ]] && alias2="$label2"

	local base1 base2
	base1=$(gpio_get_base "$label1") || { echo "$alias1 not found"; return 1; }
	base2=$(gpio_get_base "$label2") || { echo "$alias2 not found"; return 1; }

	local nr1=$((base1 + idx1))
	local nr2=$((base2 + idx2))

	test_gpio "$nr1" "$nr2" || {
		echo "$alias1:$idx1 -> $alias2:$idx2 error"
		return 1
	}

	if [ "$oneway" = "0" ]; then
		test_gpio "$nr2" "$nr1" || {
			echo "$alias2:$idx2 -> $alias1:$idx1 error"
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
		eval "$func_name() { test_gpio_pair \"$label1\" \"$idx1\" \"$label2\" \"$idx2\" \"$oneway\"; }"
		register_test "$func_name" "$test_name"
	done
}

ds_imx8m_som_evb_test_gpio() {
	local gpio1="30200000.gpio:GPIO1"
	local gpio4="30230000.gpio:GPIO4"
	local gpio5="30240000.gpio:GPIO5"

	local gpio_tests=(
		"${gpio1}	0	${gpio1}	4	GPIO1_IO00-GPIO1_IO04	0"
	)

	if dev_unbind_driver "30a60000.serial"; then
		gpio_tests+=(
			"${gpio5}	28	${gpio5}	29	UART4_RXD-UART4_TXD	0"
		)
		devmem 0x3033024c w 5
		devmem 0x30330250 w 5
	else
		register_test "test_gpio_busy" "UART4"
	fi

	if dev_unbind_driver "30a40000.i2c" && dev_unbind_driver "30a50000.i2c"; then
		gpio_tests+=(
			"${gpio5}	18	${gpio5}	20	I2C3_SCL-I2C4_SCL	0"
			"${gpio5}	19	${gpio5}	21	I2C3_SDA-I2C4_SDA	0"
		)
		devmem 0x30330224 w 5
		devmem 0x30330228 w 5
		devmem 0x3033022c w 5
		devmem 0x30330230 w 5
	else
		register_test "test_gpio_busy" "I2C3/I2C4"
	fi

	if dev_unbind_driver "30020000.sai"; then
		gpio_tests+=(
			"${gpio4}	22	${gpio4}	24	SAI2_RXC-SAI2_TXFS	0"
			"${gpio4}	23	${gpio4}	25	SAI2_RXD0-SAI2_TXC	0"
			"${gpio4}	21	${gpio4}	26	SAI2_RXFS-SAI2_TXD0	1"
			"${gpio4}	26	${gpio4}	27	SAI2_TXD0-SAI2_MCLK	1"
			"${gpio4}	27	${gpio4}	21	SAI2_MCLK-SAI2_RXFS	1"
		)
		devmem 0x303301b0 w 5
		devmem 0x303301b4 w 5
		devmem 0x303301b8 w 5
		devmem 0x303301bc w 5
		devmem 0x303301c0 w 5
		devmem 0x303301c4 w 5
		devmem 0x303301c8 w 5
	else
		register_test "test_gpio_busy" "SAI2"
	fi

	register_gpio_pair_tests "${gpio_tests[@]}"

	return 0
}

ds_rk3568_som_evb_test_gpio() {
	ver_get_ds_rk3568_som_evb_version &>/dev/null

	local oneway=0
	if [[ "$EVB_VERSION" -ge 0x121 ]]; then
		oneway=1
	fi

	local gpio_tests=(
		"gpio1 4 gpio1 6 GPIO0-GPIO1 ${oneway}"
		"gpio1 7 gpio1 8 GPIO2-GPIO3 ${oneway}"
	)

	register_gpio_pair_tests "${gpio_tests[@]}"
}

ds_rk3568_som_smarc_evb_test_gpio() {
	local gpio_tests=(
		"gpio1	2	gpio3	14	GPIO0-GPIO2	0"
		"gpio2	30	gpio3	16	GPIO4-GPIO5	0"
		"gpio3	15	gpio4	17	GPIO6-GPIO7	0"
	)

	i2c_device_test 2 0x23 &>/dev/null
	if [ $? -eq 0 ]; then
		gpio_tests+=(
			"2-0023	0	2-0023	1	GPIO8-GPIO9	0"
			"2-0023	2	2-0023	3	GPIO10-GPIO11	0"
			"2-0023	4	2-0023	5	GPIO12-GPIO13	0"
		)
	fi

	if dev_unbind_driver "fe410000.i2s"; then
		gpio_tests+=(
			"gpio3	23	gpio3	25	I2S1_CK-I2S1_SDOUT	0"
			"gpio3	24	gpio3	26	I2S1_LRCK-I2S1_SDIN	0"
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
