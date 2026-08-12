#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname "$script_dir")
. "$script_dir/test_helper.sh"
. "$repo_root/lib/common.sh"

validate_profile_quiet() { validate_profile "$@" 2>/dev/null; }
read_apt_file_quiet() { read_apt_file "$@" 2>/dev/null; }
read_tool_file_quiet() { read_tool_file "$@" 2>/dev/null; }

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

lines_file="$test_root/lines.txt"
printf '%s\n' '  zebra  ' '# comment' '' 'alpha' 'zebra' >"$lines_file"
assert_eq "$(printf 'alpha\nzebra')" "$(read_lines "$lines_file")" "read_lines normalizes comments, blanks, and duplicates"

apt_file="$test_root/apt.txt"
printf '%s\n' 'neovim 0.9.0' 'libfoo:amd64 1.2.0' 'name+variant.x-1:arm64' 'neovim 0.9.0' >"$apt_file"
assert_eq "$(printf 'libfoo:amd64\t1.2.0\nname+variant.x-1:arm64\t\nneovim\t0.9.0')" "$(read_apt_file "$apt_file")" "read_apt_file accepts Debian package and architecture syntax"

bad_whitespace="$test_root/bad-whitespace.txt"
printf '%s\n' 'too many fields here' >"$bad_whitespace"
assert_status 2 read_apt_file "$bad_whitespace"

bad_punctuation="$test_root/bad-punctuation.txt"
printf '%s\n' 'git;uname' >"$bad_punctuation"
assert_status 2 read_apt_file "$bad_punctuation"

for malformed_apt_id in '-git' '.git' '+git' 'a' 'git:' ':amd64' 'git::amd64' 'git:amd64:extra' 'git:AMD64' 'git:_amd64'; do
  malformed_apt_file="$test_root/malformed-apt.txt"
  printf '%s\n' "$malformed_apt_id" >"$malformed_apt_file"
  assert_status 2 read_apt_file "$malformed_apt_file"
done

assert_status 2 read_apt_file_quiet "$test_root/missing-apt.txt"
assert_status 2 read_tool_file_quiet npm "$test_root/missing-npm.txt"

unreadable_apt="$test_root/unreadable-apt.txt"
unreadable_tool="$test_root/unreadable-tool.txt"
printf 'git\n' >"$unreadable_apt"
printf 'prettier\n' >"$unreadable_tool"
chmod 000 "$unreadable_apt" "$unreadable_tool"
if [ -r "$unreadable_apt" ] || [ -r "$unreadable_tool" ]; then
  printf 'ok - unreadable manifest assertions skipped for privileged user\n'
else
  assert_status 2 read_apt_file_quiet "$unreadable_apt"
  assert_status 2 read_tool_file_quiet npm "$unreadable_tool"
fi
chmod 600 "$unreadable_apt" "$unreadable_tool"

mkdir -p "$test_root/profiles"
(
  cd "$test_root"
  mkdir -p manifests
  printf '%s\n' 'git' 'neovim 0.9.0' >manifests/apt-common.txt
  printf '%s\n' 'sway' >manifests/apt-sway.txt
  : >profiles/work.apt.txt
  assert_status 2 validate_profile_quiet work
  : >profiles/work.external.txt
  assert_status 0 validate_profile work
  assert_eq "$(printf 'git\t\nneovim\t0.9.0\nsway\t')" "$(load_apt_requirements work)" "load_apt_requirements merges the selected profile"

  printf '%s\n' '# managed by work' 'command zoom' 'command docker' 'command zoom' >profiles/work.external.txt
  assert_eq "$(printf 'command\tdocker\ncommand\tzoom')" "$(load_external_assumptions work)" "external assumptions are normalized records"
)

assert_status 0 validate_tool_id npm '@scope/tool-name'
assert_status 0 validate_tool_id uv 'ruff'
assert_status 2 validate_tool_id npm '--unsafe-option'
assert_status 2 validate_tool_id uv 'ruff;uname'

assert_eq "$(printf 'alpha\nbeta')" "$(append_line alpha beta)" "append_line joins non-empty values"
assert_eq beta "$(append_line '' beta)" "append_line handles an empty set"
assert_eq "$(printf 'Example\n  alpha\n  beta')" "$(print_section Example "$(printf 'alpha\nbeta')")" "print_section formats a populated section"
assert_eq "$(printf 'Empty\n  (none)')" "$(print_section Empty '')" "print_section marks an empty section"

printf 'ok - common contracts\n'
