#!/bin/bash
perl -pe 's/^\s*\d+\s+(\S)\S{31}\s+.*$/$1/' | sed 's/^[0-9a-f]$/H/' | sort | uniq -c
