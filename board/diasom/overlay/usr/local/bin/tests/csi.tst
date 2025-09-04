#!/bin/bash
# shellcheck disable=SC2329

declare -A CSI_DT_MAP=(
	["diasom,ds-rk3568-som"]=""
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_csi"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_evb_test_csi"
)

check_dependencies_csi() {
	local deps=(media-ctl v4l2-ctl)
	check_dependencies "CSI" "${deps[@]}"
}

find_csi_video_device() {
	local csi_name="$1"
	local media_dev

	for media_dev in /dev/media*; do
		[ -c "$media_dev" ] || continue

		if media-ctl -d "$media_dev" -p | grep -q "$csi_name"; then
			local videos
			videos=$(media-ctl -d "$media_dev" -p | grep -oP '/dev/video\d+' | sort -u | sort -V)

			local video
			for video in $videos; do
				if [ -c "$video" ] && v4l2-ctl -d "$video" --info 2>/dev/null | grep -q "Video Capture"; then
					echo "$video"
					return 0
				fi
			done
		fi
	done

	return 1
}

test_csi() {
	local csi_name="$1"

	cleanup() {
		if [ -n "$CSI_CONSOLE_LEVEL" ] && [ -w /proc/sys/kernel/printk ]; then
			echo "$CSI_CONSOLE_LEVEL" > /proc/sys/kernel/printk 2>/dev/null
		fi
	}
	trap cleanup EXIT RETURN INT TERM HUP

	local video_dev
	video_dev=$(find_csi_video_device "$csi_name")
	if [ -z "$video_dev" ] || [ ! -c "$video_dev" ]; then
		echo "Camera not found (Unsupported?)"
		return 1
	fi


	if [ -r /proc/sys/kernel/printk ]; then
		CSI_CONSOLE_LEVEL=$(awk '{print $1}' /proc/sys/kernel/printk 2>/dev/null)
		echo 1 > /proc/sys/kernel/printk 2>/dev/null
	fi

	local output
	output=$(timeout 4s v4l2-ctl -d "$video_dev" --stream-mmap=3 --stream-count=100 --stream-to=/dev/null 2>&1)
	local exit_code=$?
	if [ $exit_code -ne 0 ]; then
		echo "Error"
		return 1
	fi

	local fps_values
	fps_values=$(echo "$output" | grep -o '[0-9]\+\.[0-9]\+ fps' | awk '{print $1}' | tr '\n' ' ')

	if [ -z "$fps_values" ]; then
		echo "No signal"
		return 1
	fi

	local avg_fps
	avg_fps=$(echo "$fps_values" | awk '
		BEGIN { sum=0; count=0 }
		{
			for(i=1;i<=NF;i++){sum+=$i; count++}
		}
		END { print sum/count }
	')
	avg_fps=$(printf "%.1f" "$avg_fps")

	echo "${avg_fps} fps"

	return 0
}

test_rockchip_csi0() {
	test_csi rockchip-csi2-dphy0
}

ds_rk3568_som_evb_test_csi() {
	register_test "test_rockchip_csi0" "CSI0 (CAM1)"
}

ds_rk3568_som_smarc_evb_test_csi() {
	register_test "test_rockchip_csi0" "CSI (CSI1)"
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_csi || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!CSI_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${CSI_DT_MAP[$pattern]}" ]] && ${CSI_DT_MAP[$pattern]}
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
