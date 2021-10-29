#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "Exactly one argument (the path to which to compare) should be passed!"
	exit 1
fi

sort - | diff - <(cd "$1" && rk -e . | sort)
