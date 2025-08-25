#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P)

loader_bin="rk-usb-loader"
bootloader_img="barebox-diasom-rk3568-som-smarc-evb.img"

check_dependency() {
	if ! command -v "$1" &>/dev/null; then
		echo "Error: Required command '$1' not found in PATH" >&2
		return 1
	fi
}

check_file() {
	if [ ! -f "$1" ]; then
		echo "Error: Required file '$1' not found in $script_dir" >&2
		return 1
	fi
}

verify_requirements() {
	local error=0
	check_dependency "sudo" || error=1
	check_file "${script_dir}/${loader_bin}" || error=1
	check_file "${script_dir}/${bootloader_img}" || error=1
	return $error
}

main() {
	echo "This script loads the bootloader into the processor memory and runs it."
	echo
	echo "Steps:"
	echo "1. Connect USB cable from development board to computer"
	echo "2. Power on the development board"
	echo "3. Superuser privileges will be requested"
	echo
	read -n 1 -s -r -p "Press any key to begin (Ctrl+C to cancel)..."
	echo -e "\n\nStarting upload process..."

	sudo "${script_dir}/${loader_bin}" -d "${script_dir}/${bootloader_img}"

	echo -e "\nBootloader upload complete!"
}

if ! verify_requirements; then
	echo -e "\nPlease ensure all requirements are met and try again." >&2
	exit 1
fi

main

exit 0
