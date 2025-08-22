#!/bin/bash

declare -A MMC_DT_MAP=(
	["diasom,ds-rk3568-som"]="test_mmc"
	["diasom,ds-rk3568-som-evb"]="test_sd"
	["diasom,ds-rk3568-som-smarc-evb"]="test_sd"
)

check_dependencies_mmc() {
	local deps=(fio jq)
	check_dependencies "MMC" "${deps[@]}"
}

test_mmc_get_block_device() {
	local devtype="$1"

	local block
	for block in /sys/block/mmcblk*; do
		local block_name block_dev
		block_name=$(basename "$block")
		block_dev="/dev/$block_name"

		if [ ! -f "$block/device/type" ]; then
			continue
		fi

		local type
		type=$(cat "$block/device/type" 2>/dev/null)
		if [ "$type" != "$devtype" ]; then
			continue
		fi

		echo "$block_dev"

		return 0
	done

	echo "Missing"

	return 1
}

test_mmc_read_speed() {
	local devtype="$1"
	local block_dev
	block_dev=$(test_mmc_get_block_device "$devtype")
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$block_dev"
		return $ret
	fi

	local fio_output
	fio_output=$(fio --name=read_test --filename="$block_dev" --rw=read \
		--ioengine=libaio --direct=1 --iodepth=4 --bs=128k \
		--size=64M --runtime=2 --time_based --group_reporting \
		--output-format=json 2>/dev/null)

	local read_speed
	if read_speed=$(echo "$fio_output" | jq -r '.jobs[0].read.bw'); then
		read_speed=$(echo "scale=2; $read_speed / 1024" | bc)

		local min_speed
		if [ "$devtype" = "SD" ]; then
			min_speed=10
		else
			min_speed=20
		fi

		echo "${read_speed} MB/s"

		if (( $(echo "$read_speed > $min_speed" | bc -l) )); then
			return 0
		else
			return 2
		fi
	fi

	echo "Error"

	return 1
}

test_mmc_mmc() {
	test_mmc_read_speed "MMC"
}

test_mmc_sd() {
	test_mmc_read_speed "SD"
}

test_mmc() {
	register_test "test_mmc_mmc" "eMMC"
}

test_sd() {
	register_test "test_mmc_sd" "SD"
}

if ! declare -F register_test >/dev/null || ! declare -F check_dependencies >/dev/null || ! declare -F check_devicetree >/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

check_devicetree || return 1

check_dependencies_mmc || return 1

found_compatible=0
while IFS= read -r -d '' compatible; do
	compat_str=$(echo -n "$compatible" | tr -d '\0')

	for pattern in "${!MMC_DT_MAP[@]}"; do
		if [[ $compat_str == "$pattern" ]]; then
			${MMC_DT_MAP[$pattern]}
			found_compatible=1
		fi
	done
done < /proc/device-tree/compatible

if [ $found_compatible -eq 0 ]; then
	echo "Error: Cannot find suitable devicetree compatible string"
	return 1
fi

return 0
