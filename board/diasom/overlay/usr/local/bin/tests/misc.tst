#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -A MISC_DT_MAP=(
	["rockchip,rk3568"]=""
	["rockchip,rk3588"]=""
	["fsl,imx8mm"]=""
	["diasom,ds-rk3588-btb-evb-hat"]="ds_rk3588_btb_evb_hat_test_misc"
)

check_dependencies_misc() {
	local deps=("${PWM_DEPS[@]}" "${IIO_DEPS[@]}")
	deps+=(@pwm_setup @iio_get_value)
	check_dependencies "MISC" "${deps[@]}"
}

misc_pwm_adc_test() {
	local reg="$1"
	local channel="$2"
	local freq="$3"
	local adc_name="$4"
	local adc_channel="$5"

	local pwm_path
	pwm_path=$(pwm_setup "$reg" "$channel" "$freq" 1) || {
		echo "$pwm_path"
		return 1
	}

	sleep 0.2

	local sum_low=0
	local count=3
	local val
	for ((i=0; i<count; i++)); do
		val=$(iio_get_value "$adc_name" "$adc_channel") || {
			echo "$val"
			return 1
		}
		sum_low=$((sum_low + val))
		sleep 0.05
	done
	local avg_low=$((sum_low / count))

	pwm_path=$(pwm_setup "$reg" "$channel" "$freq" 99) || {
		echo "$pwm_path"
		return 1
	}

	sleep 0.2

	local sum_high=0
	for ((i=0; i<count; i++)); do
		val=$(iio_get_value "$adc_name" "$adc_channel") || {
			echo "$val"
			return 1
		}
		sum_high=$((sum_high + val))
		sleep 0.05
	done
	local avg_high=$((sum_high / count))

	local min_val=$((avg_low < avg_high ? avg_low : avg_high))
	local max_val=$((avg_low > avg_high ? avg_low : avg_high))

	if [ $min_val -eq 0 ]; then
		min_val=1
	fi

	local ratio=$(( (max_val * 100) / min_val ))
	local expected=9800
	local tolerance=2000

	local result_msg="${min_val}/${max_val}"

	echo "${result_msg}"

	if [ $ratio -ge $((expected - tolerance)) ] && [ $ratio -le $((expected + tolerance)) ]; then
		return 0
	fi

	return 2
}

register_misc_pwm_adc_test() {
	local reg="$1"
	local channel="$2"
	local freq="$3"
	local adc_name="$4"
	local adc_channel="$5"
	local description="$6"

	local func_name="misc_pwm_adc_test_${reg}_${channel}_${adc_channel}"
	func_name=$(echo "$func_name" | tr '.' '_' | tr '-' '_')

	eval "
		$func_name() {
			misc_pwm_adc_test \"$reg\" \"$channel\" \"$freq\" \"$adc_name\" \"$adc_channel\"
		}
	"
	register_test "$func_name" "$description"
}

ds_rk3588_btb_evb_hat_test_misc() {
	local tests=(
		"fd8b0010 0 1000 fec10000.adc 6 PWM1->ADC6 Feedback 1%/99%"
		"fd8b0030 0 1000 fec10000.adc 2 PWM3->ADC2 Feedback 1%/99%"
		"febd0000 0 1000 fec10000.adc 5 PWM4->ADC5 Feedback 1%/99%"
		"febf0030 0 1000 fec10000.adc 4 PWM15->ADC4 Feedback 1%/99%"
	)

	local test
	for test in "${tests[@]}"; do
		read -r reg channel freq adc_name adc_channel description <<< "$test"
		register_misc_pwm_adc_test "$reg" "$channel" "$freq" "$adc_name" "$adc_channel" "$description"
	done
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_misc || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!MISC_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${MISC_DT_MAP[$pattern]}" ]] && ${MISC_DT_MAP[$pattern]}
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
