#!/bin/sh

# Install compiled device tree overlays
for overlay in $BINARIES_DIR/*.dtbo; do
	[ -e "$overlay" ] || continue
	install -m 0644 -D $overlay $TARGET_DIR/boot
done

# Install fastboot link
[ -f $HOST_DIR/bin/fastboot ] && ln -sf $HOST_DIR/bin/fastboot $BINARIES_DIR/fastboot

exit 0
