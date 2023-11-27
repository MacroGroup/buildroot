#!/bin/sh

. /etc/profile.d/xdg.sh

if [ ! -d /sys/class/graphics/fb0 ]; then
	echo "Script cannot be used without framebuffer!"
	exit 1
fi

OUTSINK=fbdevsink
if [ -f $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY.lock ]; then
	echo "Wayland is active. Image will be dispalyed on the wayland screen!"
	OUTSINK=waylandsink
fi

gst-launch-1.0 \
videotestsrc ! \
video/x-raw,width=1920,height=1080 ! \
videoconvert ! \
$OUTSINK

exit 0
