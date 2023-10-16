#!/bin/sh

for i in gst-inspect-1.0 gst-launch-1.0; do
	if ! which $i >/dev/null 2>&1; then
		echo "Script cannot be executed due missing \"$i\" tool!"
		exit 1
	fi
done

if [ ! -d /sys/bus/platform/devices/fdee0000.video-codec ]; then
	echo "This test is not supported on this platform!"
	exit 1
fi

plugincheck()
{
	gst-inspect-1.0 --exists $1
	if [[ $? -ne 0 ]]; then
		echo "Script cannot be executed due missing \"$1\" plugin!"
		exit 1
	fi
}

timetest()
{
	echo "Measure JPEG encoding using \"$1\" plugin (1000 frames):"
	time gst-launch-1.0 -q --no-position \
	videotestsrc num-buffers=1000 ! \
	$1 ! fakesink sync=false
}

plugincheck v4l2jpegenc
plugincheck jpegenc

timetest v4l2jpegenc
timetest jpegenc

exit 0
