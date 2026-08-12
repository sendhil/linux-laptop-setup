#!/bin/bash

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
printf 'note: init/ubuntu.sh is deprecated; delegating to bin/bootstrap\n' >&2
exec "$SCRIPT_DIR/bin/bootstrap" "$@"
