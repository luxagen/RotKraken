#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "Exactly two arguments (paths to compare) should be passed!"
	exit 1
fi

rke "$1" | rkdiff-stdin "$2"
