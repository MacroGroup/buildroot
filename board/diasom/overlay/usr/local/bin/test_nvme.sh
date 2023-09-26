#!/bin/sh

NVMEM=/dev/nvme0

[ -e $NVMEM ] || { echo "NVMe disk is not found!"; exit 1; }

iozone -A -N -q 1024 -g 1024 $NVMEM

exit 0
