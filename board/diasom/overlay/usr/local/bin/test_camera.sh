#!/bin/sh

if [ -f $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY.lock ]; then
	OUTSINK=waylandsink
	echo "Wayland is active. Image will be dispalyed on the wayland screen!"
else
	OUTSINK=fbdevsink
	if [ ! -d /sys/class/graphics/fb0 ]; then
		echo "Script cannot be used without framebuffer!"
		exit 1
	fi
fi

# TODO:
#gst-launch-1.0 v4l2src device=/dev/video0 ! video/x-raw,format=UYVY,width=1920,height=1080 ! queue ! glupload ! glcolorconvert ! gldownload
#! video/x-raw,format=RGB16 ! waylandsink

#gst-launch-1.0 \
#videotestsrc ! \
#video/x-raw,width=1920,height=1080 ! \
#videoconvert ! \
#$OUTSINK

exit 0
