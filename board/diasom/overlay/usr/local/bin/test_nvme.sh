#!/bin/sh

NVME=/dev/nvme0

[ -e $NVME ] || { echo "NVMe disk is not found!"; exit 1; }

iozone -A -N -q 1024 -g 1024 $NVME

exit 0
