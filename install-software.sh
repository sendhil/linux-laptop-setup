#!/bin/bash
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ "$#" -eq 1 ] || { printf 'usage: %s PROFILE\n' "$0" >&2; exit 2; }
exec "$SCRIPT_DIR/bin/apply" "$1"
