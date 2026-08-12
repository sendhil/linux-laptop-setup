#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname "$script_dir")
. "$script_dir/test_helper.sh"
. "$repo_root/lib/inventory.sh"

dpkg-query() {
  case ${FAKE_RECORD_STATUS:-ii } in
    missing) return 1 ;;
    failure) return 2 ;;
    status) printf '%s\t1.2.3\n' "${FAKE_DPKG_STATUS:-ii }" ;;
  esac
}

FAKE_RECORD_STATUS=status
FAKE_DPKG_STATUS='ii '
assert_eq '1.2.3' "$(apt_installed_version tree)" 'normally installed package returns its version'
FAKE_DPKG_STATUS='hi '
assert_eq '1.2.3' "$(apt_installed_version tree)" 'held installed package returns its version'
FAKE_DPKG_STATUS='rc '
assert_eq '' "$(apt_installed_version tree)" 'removed package with config files is not installed'
FAKE_RECORD_STATUS=missing
assert_eq '' "$(apt_installed_version tree)" 'missing package has no installed version'
FAKE_RECORD_STATUS=failure
assert_status 2 apt_installed_version tree

printf 'ok - inventory recognizes installed and held dpkg states\n'
