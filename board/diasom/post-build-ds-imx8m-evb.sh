#!/bin/sh

ROOT=$(dirname -- $(readlink -f -- "$0"))

$ROOT/post-build-common.sh

exit 0
