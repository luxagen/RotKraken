#!/bin/bash

if [ "$#" -lt 1 ]; then
	echo "Log-file path must be the first argument!"
	exit 1
fi

logfile="$1"
shift

sudo -i rk -v "$@" | tee "$logfile" | grep '^[!SX] '
exit ${PIPESTATUS[0]}
