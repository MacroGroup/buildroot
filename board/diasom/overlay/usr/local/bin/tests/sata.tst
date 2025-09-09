#!/usr/bin/env bash
# shellcheck disable=SC2181

declare -A SATA_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-smarc-evb"]="test_sata"
)

readonly SATA1_SPEED=150
readonly SATA2_MIN_SPEED="$SATA1_SPEED"

check_dependencies_sata() {
	local deps=(fio jq)
	check_dependencies "SATA" "${deps[@]}"
}

test_sata_get_block_device() {
	for dev in /sys/block/sd*; do
		[ -e "$dev" ] || continue
		dev_name=$(basename "$dev")

		if [ -f "$dev/device/type" ]; then
			type=$(cat "$dev/device/type")
			if [ "$type" != "0" ]; then
				continue
			fi
		fi

		real_path=$(readlink -f "$dev/device" 2>/dev/null)
		[[ -z "$real_path" ]] && continue

		if [[ "$real_path" == *"/ata"* ]] || [[ "$real_path" == *"/sata"* ]] || [[ "$real_path" == *"/ahci"* ]]; then
			echo "/dev/$dev_name"
			return 0
		fi
	done

	echo -n ""

	return 1
}

test_sata_check_basic() {
	if ! dmesg | grep -i sata | grep -iq 'link up'; then
		echo "Missing"
		return 1
	fi

	local sata_dev
	sata_dev="$(test_sata_get_block_device)"

	if [ -z "$sata_dev" ] || [ ! -b "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	echo "$sata_dev"

	return 0
}

test_sata_read() {
	local sata_info speed
	speed="$SATA2_MIN_SPEED"
	sata_info=$(test_sata_check_basic)
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$sata_info"
		return $ret
	fi

	local sata_dev
	sata_dev=$(echo "$sata_info" | tail -1)
	if ! [ -b "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	local fio_output
	fio_output=$(fio --name=read_test --filename="$sata_dev" --rw=read \
		--bs=1M --iodepth=32 --direct=1 --ioengine=libaio \
		--size=10M --runtime=2 --time_based --group_reporting \
		--output-format=json 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local read_speed
	read_speed=$(echo "$fio_output" | jq -r '.jobs[0].read.bw' 2>/dev/null)

	if [[ ! "$read_speed" =~ ^[0-9.]+$ ]]; then
		echo "Error"
		return 1
	fi

	read_speed=$(echo "scale=2; $read_speed / 1024" | bc)

	echo "${read_speed} MB/s"

	register_test "@test_sata_write" "SATA Write"

	if (( $(echo "$read_speed > $speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_sata_write() {
	local sata_info speed
	speed=$(bc <<< "scale=2; $SATA2_MIN_SPEED * 0.8")
	sata_info=$(test_sata_check_basic)
	local ret=$?

	if [ $ret -ne 0 ]; then
		echo "$sata_info"
		return $ret
	fi

	local sata_dev
	sata_dev=$(echo "$sata_info" | tail -1)
	if ! [ -b "$sata_dev" ]; then
		echo "Missing"
		return 1
	fi

	local fio_output
	fio_output=$(fio --name=write_test --filename="$sata_dev" --rw=write \
		--bs=1M --direct=1 --ioengine=libaio --size=10M --runtime=2 \
		--iodepth=32 --time_based --group_reporting \
		--output-format=json 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local write_speed
	write_speed=$(echo "$fio_output" | jq -r '.jobs[0].write.bw' 2>/dev/null)

	if [[ ! "$write_speed" =~ ^[0-9.]+$ ]]; then
		echo "Error"
		return 1
	fi

	write_speed=$(echo "scale=2; $write_speed / 1024" | bc)

	echo "${write_speed} MB/s"

	if (( $(echo "$write_speed > $speed" | bc -l) )); then
		return 0
	else
		return 2
	fi
}

test_sata() {
	register_test "test_sata_read" "SATA Read"
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_sata || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!SATA_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${SATA_DT_MAP[$pattern]}" ]] && ${SATA_DT_MAP[$pattern]}
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
