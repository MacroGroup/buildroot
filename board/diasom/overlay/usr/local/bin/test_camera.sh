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

	RET=$?

	if [ $RET -ne 0 ] && $2; then
		echo "Script cannot be executed due missing \"$1\" plugin!"
		exit 1
	fi

	return $RET
}

plugincheck v4l2src true
if [ ! $(plugincheck v4l2convert false) ]; then
	FMT="video/x-raw,width=1920,height=1080"
	PIPE="v4l2convert"
	echo "Using hardware format conversion"
else
	plugincheck glupload true
	plugincheck glcolorconvert true
	plugincheck gldownload true
	FMT="video/x-raw,format=UYVY,width=1920,height=1080"
	PIPE="queue ! glupload ! glcolorconvert ! gldownload"
	echo "Using OpenGL format conversion"
fi

plugincheck waylandsink true

gst-launch-1.0 \
v4l2src device=/dev/video0 ! \
$FMT ! \
$PIPE ! \
video/x-raw,format=RGB16 ! waylandsink

exit 0
