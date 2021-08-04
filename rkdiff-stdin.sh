#!/bin/bash
sort - | diff - <(rk -e . | sort)
