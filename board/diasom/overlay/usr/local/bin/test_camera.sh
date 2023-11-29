#!/bin/sh

if [ ! -f $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY.lock ]; then
	echo "Script works on Wayland screen only!"
	exit 1
fi

# TODO:
# gst-launch-1.0 \
# v4l2src device=/dev/video0 ! \
# video/x-raw,format=UYVY,width=1920,height=1080 ! \
# queue ! \
# glupload ! \
# glcolorconvert ! \
# gldownload video/x-raw,format=RGB16 ! \
# waylandsink

exit 0
