#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

test_repo="$tmp_dir/repository"
fake_bin="$tmp_dir/fake-bin"
fake_home="$tmp_dir/home"
npm_cache="$tmp_dir/npm-cache"
runtime_tmp="$tmp_dir/runtime-tmp"
state_dir="$tmp_dir/state"
call_log="$tmp_dir/calls.log"
manager_log="$tmp_dir/manager-calls.log"
mkdir -p "$test_repo" "$fake_bin" "$fake_home" "$npm_cache" "$runtime_tmp" "$state_dir"
cp -R "$repo_dir"/. "$test_repo"/

cat >"$tmp_dir/os-release" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
EOF

cat >"$test_repo/manifests/apt-common.txt" <<'EOF'
bat
neovim 0.9.0
tree
EOF
printf '# Empty for apply test.\n' >"$test_repo/manifests/apt-sway.txt"
printf '# Empty for apply test.\n' >"$test_repo/profiles/work.apt.txt"
printf 'prettier\n' >"$test_repo/manifests/npm.txt"
printf 'ruff\n' >"$test_repo/manifests/uv-tools.txt"
# Apply must never read or act on this diagnostic-only manifest.
printf 'this is intentionally invalid slack zoom\n' >"$test_repo/profiles/work.external.txt"

printf 'bat\n' >"$state_dir/apt"
: >"$state_dir/npm"
: >"$state_dir/uv"
: >"$call_log"
: >"$manager_log"

cat >"$fake_bin/dpkg-query" <<'EOF'
#!/bin/bash
package=${!#}
printf 'dpkg-query <%s>\n' "$package" >>"$FAKE_MANAGER_LOG"
[ "${FAKE_DPKG_FAILURE:-}" != "$package" ] || exit 2
grep -Fx "$package" "$FAKE_STATE_DIR/apt" >/dev/null 2>&1 || exit 1
version=1.0
[ "$package" != neovim ] || version=${FAKE_NEOVIM_VERSION:-0.9.0}
status='ii '
[ "${FAKE_HELD_APT:-}" != "$package" ] || status='hi '
printf '%s\t%s\n' "$status" "$version"
EOF

cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
printf 'dpkg <%s>\n' "${1:-}" >>"$FAKE_MANAGER_LOG"
case ${1:-} in
  --print-architecture) printf 'amd64\n' ;;
  --compare-versions)
    [ "$3" = ge ] || exit 2
    [ "$2" != 0.8.4 ] || exit 1
    exit 0
    ;;
  *) exit 2 ;;
esac
EOF

cat >"$fake_bin/apt-cache" <<'EOF'
#!/bin/bash
package=${!#}
printf 'apt-cache <%s>\n' "$package" >>"$FAKE_MANAGER_LOG"
[ "${FAKE_APT_CACHE_FAILURE:-}" != "$package" ] || exit 2
case $package in
  neovim) candidate=${FAKE_NEOVIM_CANDIDATE:-0.9.0} ;;
  *) candidate=${FAKE_APT_CANDIDATE:-1.0} ;;
esac
printf '%s:\n  Candidate: %s\n' "$package" "$candidate"
EOF

cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
exec "$@"
EOF

cat >"$fake_bin/apt-get" <<'EOF'
#!/bin/bash
printf 'apt-get' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
[ "${FAKE_APT_FAILURE:-}" != "${1:-}" ] || exit 1
case ${1:-} in
  update) exit 0 ;;
  install)
    package=${!#}
    grep -Fx "$package" "$FAKE_STATE_DIR/apt" >/dev/null 2>&1 || printf '%s\n' "$package" >>"$FAKE_STATE_DIR/apt"
    ;;
  *) exit 64 ;;
esac
EOF

cat >"$fake_bin/npm" <<'EOF'
#!/bin/bash
case ${1:-} in
  list)
    printf 'npm <list>\n' >>"$FAKE_MANAGER_LOG"
    [ -d "${npm_config_cache:-}" ] || exit 90
    case ${npm_config_cache:-} in "$HOME"|"$HOME"/*) exit 91 ;; esac
    [ "${NODE_DISABLE_COMPILE_CACHE:-}" = 1 ] || exit 92
    [ "${npm_config_logs_max:-}" = 0 ] || exit 93
    [ "${npm_config_update_notifier:-}" = false ] || exit 94
    [ "${npm_config_audit:-}" = false ] || exit 95
    [ "${npm_config_fund:-}" = false ] || exit 96
    [ "${npm_config_progress:-}" = false ] || exit 97
    while IFS= read -r package; do
      [ -n "$package" ] && printf '/opt/npm/lib/node_modules/%s\n' "$package"
    done <"$FAKE_STATE_DIR/npm"
    ;;
  install)
    printf 'npm' >>"$FAKE_CALL_LOG"
    printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
    printf '\n' >>"$FAKE_CALL_LOG"
    [ "${FAKE_NPM_INSTALL_FAILURE:-0}" -eq 0 ] || exit 1
    package=${!#}
    grep -Fx "$package" "$FAKE_STATE_DIR/npm" >/dev/null 2>&1 || printf '%s\n' "$package" >>"$FAKE_STATE_DIR/npm"
    ;;
  *) exit 64 ;;
esac
EOF

cat >"$fake_bin/uv" <<'EOF'
#!/bin/bash
case ${1:-} in
  tool)
    case ${2:-} in
      list)
        printf 'uv <tool-list>\n' >>"$FAKE_MANAGER_LOG"
        [ "${UV_NO_CACHE:-}" = 1 ] || exit 90
        [ "${UV_NO_PROGRESS:-}" = 1 ] || exit 91
        while IFS= read -r package; do
          [ -n "$package" ] && printf '%s 1.0\n' "$package"
        done <"$FAKE_STATE_DIR/uv"
        ;;
      install)
        printf 'uv' >>"$FAKE_CALL_LOG"
        printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
        printf '\n' >>"$FAKE_CALL_LOG"
        [ "${FAKE_UV_INSTALL_FAILURE:-0}" -eq 0 ] || exit 1
        package=${!#}
        grep -Fx "$package" "$FAKE_STATE_DIR/uv" >/dev/null 2>&1 || printf '%s\n' "$package" >>"$FAKE_STATE_DIR/uv"
        ;;
      *) exit 64 ;;
    esac
    ;;
  *) exit 64 ;;
esac
EOF

chmod +x "$fake_bin"/*

run_apply() {
  : >"$call_log"
  : >"$manager_log"
  set +e
  apply_output=$(cd "$test_repo" && env \
    HOME="$fake_home" \
    TMPDIR="$runtime_tmp" \
    PATH="$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="$tmp_dir/os-release" \
    SETUP_AUDIT_NPM_CACHE="$npm_cache" \
    SETUP_SUDO_COMMAND="${SETUP_SUDO_COMMAND:-sudo}" \
    FAKE_STATE_DIR="$state_dir" \
    FAKE_CALL_LOG="$call_log" \
    FAKE_MANAGER_LOG="$manager_log" \
    FAKE_DPKG_FAILURE="${FAKE_DPKG_FAILURE:-}" \
    FAKE_HELD_APT="${FAKE_HELD_APT:-}" \
    FAKE_APT_CACHE_FAILURE="${FAKE_APT_CACHE_FAILURE:-}" \
    FAKE_APT_CANDIDATE="${FAKE_APT_CANDIDATE:-1.0}" \
    FAKE_NEOVIM_CANDIDATE="${FAKE_NEOVIM_CANDIDATE:-0.9.0}" \
    FAKE_APT_FAILURE="${FAKE_APT_FAILURE:-}" \
    FAKE_NPM_INSTALL_FAILURE="${FAKE_NPM_INSTALL_FAILURE:-0}" \
    FAKE_UV_INSTALL_FAILURE="${FAKE_UV_INSTALL_FAILURE:-0}" \
    bash bin/apply work 2>&1)
  apply_status=$?
  set -e
}

assert_no_mutation() {
  [ ! -s "$call_log" ] || fail "$1 (unexpected calls: $(tr '\n' ' ' <"$call_log"))"
}

assert_no_manager_call() {
  [ ! -s "$manager_log" ] || fail "$1 (unexpected calls: $(tr '\n' ' ' <"$manager_log"))"
}

run_apply
assert_eq 0 "$apply_status" 'apply installs a valid missing plan'
calls=$(cat "$call_log")
assert_eq 1 "$(grep -c '^apt-get <update>$' "$call_log")" 'APT metadata updates exactly once'
assert_contains "$calls" 'apt-get <install> <-y> <--no-install-recommends> <--> <neovim>' 'neovim install is individual and option-terminated'
assert_contains "$calls" 'apt-get <install> <-y> <--no-install-recommends> <--> <tree>' 'tree install is individual and option-terminated'
case $calls in *'<bat>'*) fail 'satisfied APT package is not reinstalled' ;; esac
assert_contains "$calls" 'npm <install> <--global> <prettier>' 'missing npm tool is installed'
assert_contains "$calls" 'uv <tool> <install> <ruff>' 'missing uv tool is installed'

run_apply
assert_eq 0 "$apply_status" 'a completed apply is safely resumable'
assert_no_mutation 'a completed rerun skips every manager mutation'

# Every preflight failure below must happen before the first mutation.
printf 'bat\n' >"$test_repo/profiles/work.apt.txt"
run_apply
assert_eq 2 "$apply_status" 'duplicate APT package across common and profile manifests is invalid configuration'
assert_no_mutation 'identical layered APT duplicate is rejected before mutation'
assert_no_manager_call 'identical layered APT duplicate is rejected before manager inventory'

printf 'neovim 1.0.0\n' >"$test_repo/profiles/work.apt.txt"
run_apply
assert_eq 2 "$apply_status" 'layered APT package with differing floors is invalid configuration'
assert_no_mutation 'differing layered APT floor is rejected before mutation'
assert_no_manager_call 'differing layered APT floor is rejected before manager inventory'
printf '# Empty for apply test.\n' >"$test_repo/profiles/work.apt.txt"

FAKE_HELD_APT=bat run_apply
assert_eq 0 "$apply_status" 'a held installed APT package is satisfied'
assert_no_mutation 'a held package does not trigger APT mutation'

printf '%s\n' '--unsafe' >"$test_repo/manifests/npm.txt"
printf 'tree\n' | LC_ALL=C sort -u >"$state_dir/apt"
run_apply
assert_eq 2 "$apply_status" 'unsafe tool ID is invalid configuration'
assert_no_mutation 'unsafe tool ID is rejected before mutation'
printf 'prettier\n' >"$test_repo/manifests/npm.txt"

mv "$fake_bin/npm" "$fake_bin/npm.saved"
run_apply
assert_eq 2 "$apply_status" 'a needed unavailable manager is invalid configuration'
assert_no_mutation 'unavailable manager is rejected before mutation'
mv "$fake_bin/npm.saved" "$fake_bin/npm"

printf 'bat\n' >"$state_dir/apt"
FAKE_NEOVIM_CANDIDATE=0.8.4 run_apply
assert_eq 2 "$apply_status" 'candidate below a declared floor is rejected'
assert_no_mutation 'insufficient candidate is rejected before mutation'

FAKE_APT_CACHE_FAILURE=tree run_apply
assert_eq 2 "$apply_status" 'candidate inventory failure preserves configuration status'
assert_no_mutation 'candidate inventory failure occurs before mutation'

SETUP_SUDO_COMMAND=unavailable-sudo run_apply
assert_eq 2 "$apply_status" 'missing privilege for an APT plan is invalid configuration'
assert_no_mutation 'unavailable sudo is rejected before mutation'

# Mutation failures are status 1; already-completed work remains installed for rerun.
printf 'bat\n' >"$state_dir/apt"
: >"$state_dir/npm"
: >"$state_dir/uv"
FAKE_NPM_INSTALL_FAILURE=1 run_apply
assert_eq 1 "$apply_status" 'manager install failure exits with status 1'
assert_contains "$apply_output" 'failed to install npm tool: prettier' 'failed item is reported'
assert_contains "$apply_output" 'rerun: bin/apply work' 'failure reports a safe rerun command'
grep -Fx neovim "$state_dir/apt" >/dev/null || fail 'completed APT work is preserved after later failure'
grep -Fx tree "$state_dir/apt" >/dev/null || fail 'all completed APT installs remain resumable'

case $(cat "$call_log") in
  *remove*|*purge*|*autoremove*|*upgrade*|*dist-upgrade*|*full-upgrade*|*slack*|*zoom*)
    fail 'apply log contains a forbidden or external action'
    ;;
esac

set +e
wrapper_output=$(cd "$test_repo" && bash install-software.sh 2>&1)
wrapper_status=$?
set -e
assert_eq 2 "$wrapper_status" 'compatibility wrapper requires exactly one profile'
assert_contains "$wrapper_output" 'usage:' 'compatibility wrapper prints usage'

printf 'ok - apply validates completely, installs additively, and resumes safely\n'
