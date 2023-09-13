#!/bin/sh

gst-launch-1.0 videotestsrc ! videoconvert ! fbdevsink

exit 0
