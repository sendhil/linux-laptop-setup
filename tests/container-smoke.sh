#!/bin/bash
set -eu

usage() {
  printf 'usage: %s [IMAGE]\n' "$0" >&2
}

if [ "$#" -gt 1 ]; then
  usage
  exit 2
fi

image=ubuntu:24.04
if [ "$#" -eq 1 ]; then
  image=$1
fi

if [[ ! $image =~ ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$ ]]; then
  printf 'error: IMAGE must be a non-option Docker image reference\n' >&2
  usage
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP: Docker is unavailable; container smoke test not run.\n'
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  printf 'SKIP: Docker daemon is unavailable; container smoke test not run.\n'
  exit 0
fi

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

docker run --rm \
  -v "$repo:/repo:ro" \
  -w /repo \
  "$image" \
  bash -lc '
    apt-get update >/dev/null
    apt-get install -y bash coreutils desktop-file-utils findutils git grep libdigest-sha-perl python3 sed >/dev/null
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0=/repo
    bash tests/run
    bash -n bin/bootstrap bin/audit bin/apply bin/doctor bin/audit-wine bin/install-sway-nvidia-session bin/install-wezterm bin/setup-work-laptop
  '
