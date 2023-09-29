#!/bin/sh

# Install compiled device tree overlays
install -m 0644 -D $BINARIES_DIR/*.dtbo $TARGET_DIR/boot

exit 0
