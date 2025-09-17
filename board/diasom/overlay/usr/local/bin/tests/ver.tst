#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

declare -A VER_DT_MAP=(
	["diasom,ds-imx8m-som"]=""
	["diasom,ds-rk3568-som"]="ds_rk3568_som_test_version"
	["diasom,ds-rk3568-som-evb"]="ds_rk3568_som_evb_test_version"
	["diasom,ds-rk3568-som-smarc-evb"]="ds_rk3568_som_smarc_test_version"
)

check_dependencies_ver() {
	local deps=("${VER_DEPS[@]}")
	deps+=(@ver_get_ds_rk3568_som_version @ver_get_ds_rk3568_som_evb_version)
	deps+=(@ver_get_ds_rk3568_som_smarc_version)
	check_dependencies "VER" "${deps[@]}"
}

ds_rk3568_som_test_version() {
	register_test "@@ver_get_ds_rk3568_som_version" "SOM Version"
}

ds_rk3568_som_evb_test_version() {
	register_test "@@ver_get_ds_rk3568_som_evb_version" "EVB Version"
}

ds_rk3568_som_smarc_test_version() {
	register_test "@@ver_get_ds_rk3568_som_smarc_version" "SMARC Version"
}

if ! declare -F check_dependencies &>/dev/null; then
	echo "Script cannot be executed alone"

	return 1
fi

if [ -f /proc/device-tree/compatible ]; then
	check_dependencies_ver || return 1

	found_compatible=0
	while IFS= read -r -d '' compatible; do
		compat_str=$(echo -n "$compatible" | tr -d '\0')

		for pattern in "${!VER_DT_MAP[@]}"; do
			if [[ $compat_str == "$pattern" ]]; then
				[[ -n "${VER_DT_MAP[$pattern]}" ]] && ${VER_DT_MAP[$pattern]}
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
