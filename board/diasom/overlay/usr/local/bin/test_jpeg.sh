#!/bin/sh

if [ ! -d /sys/bus/platform/devices/fdee0000.video-codec ]; then
	echo "Test JPEG is not supported on this platform!"
	exit 1
fi

echo "Measure JPEG hardware encoding (1000 frames):"
time gst-launch-1.0 -q --no-position videotestsrc num-buffers=1000 ! \
v4l2jpegenc ! fakesink sync=false

echo "Measure JPEG software encoding (1000 frames):"
time gst-launch-1.0 -q --no-position videotestsrc num-buffers=1000 ! \
jpegenc ! fakesink sync=false

exit 0
