#!/bin/bash
diff <(cd "$1" && rk -e . | sort) <(cd "$2" && rk -e . | sort)
