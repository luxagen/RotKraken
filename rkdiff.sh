#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "Exactly two arguments (paths to compare) required"
	exit 1
fi

if [ ! -e "$1" ]; then echo "Directory not found: '$1'"; fi
if [ ! -e "$2" ]; then echo "Directory not found: '$2'"; fi
if [ ! -e "$1" ] || [ ! -e "$2" ]; then exit 2; fi

set -e

rke "$1" | rkdiff-stdin "$2"
