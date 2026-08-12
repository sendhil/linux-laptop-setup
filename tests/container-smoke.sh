#!/bin/bash
set -eu

image=${1:-ubuntu:24.04}

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
    apt-get install -y bash coreutils findutils git grep sed >/dev/null
    bash tests/run
    bash -n bin/bootstrap bin/audit bin/apply bin/doctor
  '
