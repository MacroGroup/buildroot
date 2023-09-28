#!/bin/sh

[ -f /sys/class/graphics/fb0 ] || { echo "Script cannot be executed without framebuffer!"; exit 1; }

gst-launch-1.0 \
videotestsrc ! \
video/x-raw,width=1920,height=1080 ! \
videoconvert ! \
fbdevsink

exit 0
