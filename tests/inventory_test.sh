#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname "$script_dir")
. "$script_dir/test_helper.sh"
. "$repo_root/lib/inventory.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

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

uv() {
  printf 'uv was invoked\n' >"$tmp_dir/uv-invoked"
  return 99
}

run_uv_inventory() {
  set +e
  uv_output=$(uv_inventory 2>&1)
  uv_status=$?
  set -e
}

uv_inventory_quiet() { uv_inventory 2>/dev/null; }

fake_home="$tmp_dir/home"
mkdir -p "$fake_home"
HOME=$fake_home
unset UV_TOOL_DIR XDG_DATA_HOME
assert_eq '' "$(uv_inventory)" 'missing default uv tool directory is an empty inventory'
[ ! -e "$fake_home/.local" ] || fail 'uv inventory does not create its default directory'
[ ! -e "$tmp_dir/uv-invoked" ] || fail 'uv inventory never invokes the uv executable'

xdg_data="$tmp_dir/xdg-data"
mkdir -p "$xdg_data/uv/tools/ruff"
XDG_DATA_HOME=$xdg_data
assert_eq 'ruff' "$(uv_inventory)" 'XDG data home selects the uv tools directory when no override is set'
unset XDG_DATA_HOME

home_tools="$fake_home/.local/share/uv/tools"
mkdir -p "$home_tools/home-tool"
XDG_DATA_HOME=relative-data
assert_eq 'home-tool' "$(uv_inventory)" 'relative XDG data home falls back to the absolute HOME path'
XDG_DATA_HOME=''
assert_eq 'home-tool' "$(uv_inventory)" 'empty XDG data home falls back to the absolute HOME path'
unset XDG_DATA_HOME

HOME=relative-home
run_uv_inventory
assert_eq 2 "$uv_status" 'relative HOME is invalid when resolving the default uv tools path'
assert_contains "$uv_output" 'HOME must be absolute' 'relative HOME failure is explicit'
HOME=$fake_home

UV_TOOL_DIR=relative-tools
run_uv_inventory
assert_eq 2 "$uv_status" 'relative explicit uv tools directory is invalid'
assert_contains "$uv_output" 'UV_TOOL_DIR must be absolute' 'relative uv tools failure is explicit'
UV_TOOL_DIR=''
run_uv_inventory
assert_eq 2 "$uv_status" 'empty explicit uv tools directory is invalid'
unset UV_TOOL_DIR

uv_tools="$tmp_dir/uv-tools"
mkdir -p "$uv_tools/ruff" "$uv_tools/python-lsp-server" "$uv_tools/.hidden-tool" \
  "$uv_tools/tool_name" "$uv_tools/tool.name" "$uv_tools/nested/child" \
  "$uv_tools/"$'invalid\nruff'
mkdir -p "$tmp_dir/symlink-target"
ln -s "$tmp_dir/symlink-target" "$uv_tools/symlink-tool"
printf 'lock sentinel\n' >"$uv_tools/.lock"
printf 'file sentinel\n' >"$uv_tools/file-only"
snapshot_before=$(find "$uv_tools" -print -exec shasum {} \; 2>/dev/null | LC_ALL=C sort)
UV_TOOL_DIR=$uv_tools
HOME=relative-home
XDG_DATA_HOME=$xdg_data
assert_eq "$(printf 'nested\npython-lsp-server\nruff')" "$(uv_inventory)" 'uv inventory returns only immediate canonical tool directories'
HOME=$fake_home
unset XDG_DATA_HOME
snapshot_after=$(find "$uv_tools" -print -exec shasum {} \; 2>/dev/null | LC_ALL=C sort)
assert_eq "$snapshot_before" "$snapshot_after" 'uv inventory leaves tool directories, files, and lock state unchanged'
[ ! -e "$tmp_dir/uv-invoked" ] || fail 'filesystem uv inventory does not invoke uv'

valid_root_link="$tmp_dir/valid-root-link"
dangling_root_link="$tmp_dir/dangling-root-link"
ln -s "$uv_tools" "$valid_root_link"
ln -s "$tmp_dir/missing-root" "$dangling_root_link"
UV_TOOL_DIR=$valid_root_link
run_uv_inventory
assert_eq 2 "$uv_status" 'symlink uv tools root is rejected even when its target is valid'
assert_contains "$uv_output" 'must not be a symbolic link' 'valid root symlink failure is explicit'
UV_TOOL_DIR=$valid_root_link/
run_uv_inventory
assert_eq 2 "$uv_status" 'symlink uv tools root cannot bypass validation with a trailing slash'
assert_contains "$uv_output" 'must not be a symbolic link' 'trailing-slash root symlink failure is explicit'
UV_TOOL_DIR=$dangling_root_link
run_uv_inventory
assert_eq 2 "$uv_status" 'dangling uv tools root symlink is rejected'
assert_contains "$uv_output" 'must not be a symbolic link' 'dangling root symlink failure is explicit'

uv_tools_file="$tmp_dir/uv-tools-file"
printf 'not a directory\n' >"$uv_tools_file"
UV_TOOL_DIR=$uv_tools_file
assert_status 2 uv_inventory_quiet

unreadable_tools="$tmp_dir/unreadable-tools"
mkdir -p "$unreadable_tools"
chmod 000 "$unreadable_tools"
if [ ! -r "$unreadable_tools" ]; then
  UV_TOOL_DIR=$unreadable_tools
  assert_status 2 uv_inventory_quiet
fi
chmod 700 "$unreadable_tools"

printf 'ok - inventory recognizes dpkg state and reads uv tools without mutation\n'
