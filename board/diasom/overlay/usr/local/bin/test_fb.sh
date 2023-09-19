#!/bin/sh

gst-launch-1.0 \
videotestsrc ! \
video/x-raw,width=1920,height=1080 ! \
videoconvert ! \
fbdevsink

exit 0
