#!/bin/sh

if [ ! -d /sys/bus/platform/devices/fdee0000.video-codec ]; then
	echo "HW JPEG encoding test is not supported on this platform!"
	exit 1
fi

timetest()
{
	time gst-launch-1.0 -q --no-position \
	videotestsrc num-buffers=1000 ! \
	$1 ! fakesink sync=false
}

echo "Measure JPEG hardware encoding (1000 frames):"
timetest v4l2jpegenc

echo "Measure JPEG software encoding (1000 frames):"
timetest jpegenc

exit 0
