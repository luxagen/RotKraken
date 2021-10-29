#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "Exactly two arguments (paths to compare) should be passed!"
	exit 1
fi

(cd "$1" && rk -e .) | rkdiff-stdin "$2"
