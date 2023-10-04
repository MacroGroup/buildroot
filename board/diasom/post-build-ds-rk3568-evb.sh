#!/bin/sh

ROOT=$(dirname -- $(readlink -f -- "$0"))

$ROOT/post-build-common.sh

install -m 0755 -D $ROOT/upload_boot.sh $BINARIES_DIR

exit 0
