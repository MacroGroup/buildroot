#!/usr/bin/env bash

set -e

for var in BINARIES_DIR TARGET_DIR HOST_DIR; do
	eval "value=\"\${$var}\""
	if [ -z "$value" ]; then
		echo "Error: $var is not set" >&2
		exit 1
	fi
done

if [ -d "$BINARIES_DIR" ]; then
	for overlay in "$BINARIES_DIR"/*.dtbo; do
		[ -f "$overlay" ] || continue
		filename="${overlay##*/}"
		install -m 0644 -D "$overlay" "${TARGET_DIR}/boot/${filename}"
	done
else
	echo "Warning: BINARIES_DIR '$BINARIES_DIR' does not exist" >&2
fi

if [ -f "${HOST_DIR}/bin/fastboot" ]; then
	mkdir -p "$BINARIES_DIR"
	ln -sf "${HOST_DIR}/bin/fastboot" "${BINARIES_DIR}/fastboot"
fi

exit 0
