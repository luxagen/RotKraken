#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "Exactly one argument (path to log) should be passed!"
	exit 1
fi

cd "$1" && rk -e .
