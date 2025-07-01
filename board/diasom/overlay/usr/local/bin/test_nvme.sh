#!/bin/sh

set -e

NVME=/dev/nvme0

[ -e $NVME ] || { echo "NVMe disk is not found!"; exit 1; }

NVMEPART=/dev/nvme0n1

if [ -e $NVMEPART ]; then
	fio --name=test --filename=$NVMEPART --ioengine=libaio --rw=randrw \
		--bs=4k --numjobs=$(nproc) --size=1G --runtime=60 \
		--time_based --direct=1 --eta=always --iodepth=32 || exit 1
else
	iozone -A -I -N -q 1024 -g 1024 $NVME || exit 1
fi

exit 0
