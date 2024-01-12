#!/bin/sh

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

timetest()
{
	echo "Measure image scaling using \"$1\" plugin (10 frames):"
	time -f %U gst-launch-1.0 -q --no-position \
	videotestsrc num-buffers=10 ! \
	video/x-raw,width=1920,height=1080 ! \
	$1 ! \
	video/x-raw,width=800,height=600 ! \
	fakesink sync=false
}

plugincheck videotestsrc
plugincheck fakesink
plugincheck videoscale
plugincheck v4l2convert

timetest v4l2convert
timetest videoscale

exit 0
