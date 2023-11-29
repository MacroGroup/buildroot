#!/bin/sh

if [ ! -f $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY.lock ]; then
	echo "Script works on Wayland screen only!"
	exit 1
fi

for i in gst-inspect-1.0 gst-launch-1.0; do
	if ! which $i >/dev/null 2>&1; then
		echo "Script cannot be executed due missing \"$i\" tool!"
		exit 1
	fi
done

plugincheck()
{
	gst-inspect-1.0 --exists $1
	if [[ $? -ne 0 ]]; then
		echo "Script cannot be executed due missing \"$1\" plugin!"
		exit 1
	fi
}

plugincheck v4l2src
plugincheck glupload
plugincheck glcolorconvert
plugincheck gldownload
plugincheck waylandsink

gst-launch-1.0 \
v4l2src device=/dev/video0 ! \
video/x-raw,format=UYVY,width=1920,height=1080 ! \
queue ! \
glupload ! \
glcolorconvert ! \
gldownload ! \
video/x-raw,format=RGB16 ! \
waylandsink

exit 0
