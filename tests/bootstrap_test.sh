#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

test_repo="$tmp_dir/repository"
fake_bin="$tmp_dir/fake-bin"
safe_bin="$tmp_dir/safe-bin"
state_dir="$tmp_dir/state"
call_log="$tmp_dir/calls.log"
mkdir -p "$test_repo" "$fake_bin" "$safe_bin" "$state_dir"
cp -R "$repo_dir"/. "$test_repo"/

for command_name in awk dirname grep paste sed; do
  ln -s "$(command -v "$command_name")" "$safe_bin/$command_name"
done

ubuntu_release="$tmp_dir/ubuntu-os-release"
cat >"$ubuntu_release" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
EOF

debian_release="$tmp_dir/debian-os-release"
cat >"$debian_release" <<'EOF'
ID=debian
VERSION_ID="12"
VERSION_CODENAME=bookworm
EOF

cat >"$fake_bin/dpkg-query" <<'EOF'
#!/bin/bash
package=${!#}
[ "${FAKE_DPKG_FAILURE:-}" != "$package" ] || exit 2
grep -Fx "$package" "$FAKE_STATE_DIR/apt" >/dev/null 2>&1 || exit 1
printf 'ii \t1.0\n'
EOF

cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
[ "${1:-}" = --print-architecture ] || exit 2
printf 'amd64\n'
EOF

cat >"$fake_bin/lspci" <<'EOF'
#!/bin/bash
cat <<'OUTPUT'
00:02.0 VGA compatible controller: Intel Corporation Example Graphics
  Kernel driver in use: i915
01:00.0 3D controller: NVIDIA Corporation Example Discrete Graphics
  Kernel driver in use: nouveau
OUTPUT
EOF

cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
if [ "${1:-}" = -v ] && [ "$#" -eq 1 ]; then
  [ "${FAKE_SUDO_MODE:-allowed}" = allowed ]
  exit $?
fi
[ "${FAKE_SUDO_MODE:-allowed}" = allowed ] || exit 1
exec "$@"
EOF

cat >"$fake_bin/apt-get" <<'EOF'
#!/bin/bash
printf 'apt-get' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
case ${1:-} in
  update) [ "$#" -eq 1 ] || exit 64 ;;
  install)
    [ "$#" -eq 5 ] || exit 64
    [ "$2" = -y ] || exit 64
    [ "$3" = --no-install-recommends ] || exit 64
    [ "$4" = -- ] || exit 64
    package=$5
    grep -Fx "$package" "$FAKE_STATE_DIR/apt" >/dev/null 2>&1 || \
      printf '%s\n' "$package" >>"$FAKE_STATE_DIR/apt"
    ;;
  *) exit 64 ;;
esac
EOF

for forbidden in curl git systemctl service modprobe ubuntu-drivers; do
  cat >"$fake_bin/$forbidden" <<EOF
#!/bin/bash
printf '$forbidden' >>"\$FAKE_CALL_LOG"
printf ' <%s>' "\$@" >>"\$FAKE_CALL_LOG"
printf '\n' >>"\$FAKE_CALL_LOG"
exit 97
EOF
done
chmod +x "$fake_bin"/*

run_bootstrap() {
  : >"$call_log"
  set +e
  bootstrap_output=$(cd "$test_repo" && env \
    PATH="${BOOTSTRAP_PATH:-$fake_bin:/usr/bin:/bin}" \
    SETUP_OS_RELEASE="${SETUP_OS_RELEASE:-$ubuntu_release}" \
    SETUP_SUDO_COMMAND="${SETUP_SUDO_COMMAND:-}" \
    FAKE_STATE_DIR="$state_dir" \
    FAKE_CALL_LOG="$call_log" \
    FAKE_DPKG_FAILURE="${FAKE_DPKG_FAILURE:-}" \
    FAKE_SUDO_MODE="${FAKE_SUDO_MODE:-allowed}" \
    /bin/bash bin/bootstrap 2>&1)
  bootstrap_status=$?
  set -e
}

assert_no_mutation() {
  [ ! -s "$call_log" ] || \
    fail "$1 (unexpected calls: $(tr '\n' ' ' <"$call_log"))"
}

assert_no_apt_call() {
  case $(cat "$call_log") in
    *apt-get*) fail "$1 (unexpected calls: $(tr '\n' ' ' <"$call_log"))" ;;
  esac
}

run_invalid_bootstrap_arg() {
  : >"$call_log"
  set +e
  bootstrap_output=$(cd "$test_repo" && env \
    PATH="$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="$tmp_dir/does-not-exist" \
    FAKE_STATE_DIR="$state_dir" \
    FAKE_CALL_LOG="$call_log" \
    /bin/bash bin/bootstrap unexpected 2>&1)
  bootstrap_status=$?
  set -e
}

run_invalid_bootstrap_arg
assert_eq 2 "$bootstrap_status" 'bootstrap accepts exactly zero arguments'
assert_contains "$bootstrap_output" 'usage: bin/bootstrap' 'invalid bootstrap arguments print usage'
case $bootstrap_output in
  *platform*|*Ubuntu*|*Architecture*|*Graphics*)
    fail 'argument validation runs after platform detection'
    ;;
esac
assert_no_mutation 'invalid arguments are rejected before inventory or mutation'

printf 'ca-certificates\ngit\n' >"$state_dir/apt"
run_bootstrap
assert_eq 0 "$bootstrap_status" 'a prepared Ubuntu machine needs no bootstrap mutation'
assert_contains "$bootstrap_output" 'Ubuntu: 24.04 (noble)' 'bootstrap prints Ubuntu version and codename'
assert_contains "$bootstrap_output" 'Architecture: amd64' 'bootstrap prints the architecture'
assert_contains "$bootstrap_output" 'Intel Corporation Example Graphics' 'bootstrap prints the read-only GPU summary'
assert_contains "$bootstrap_output" 'Kernel driver in use: nouveau' 'bootstrap prints the discoverable graphics driver'
assert_no_mutation 'satisfied prerequisites do not require sudo or APT'

printf 'git\n' >"$state_dir/apt"
run_bootstrap
assert_eq 0 "$bootstrap_status" 'one missing prerequisite is installed'
assert_eq 'sudo <-v>' "$(sed -n '1p' "$call_log")" \
  'bootstrap refreshes sudo credentials before any APT call'
case $(cat "$call_log") in
  *'<true>'*) fail 'bootstrap uses true as a sudo authorization probe' ;;
esac
assert_eq 1 "$(grep -c '^apt-get <update>$' "$call_log")" 'APT metadata updates once when a prerequisite is missing'
assert_contains "$(cat "$call_log")" \
  'apt-get <install> <-y> <--no-install-recommends> <--> <ca-certificates>' \
  'the missing prerequisite is installed with an option terminator'
case $(cat "$call_log") in
  *'<git>'*) fail 'an installed bootstrap prerequisite is not reinstalled' ;;
esac
run_bootstrap
assert_eq 0 "$bootstrap_status" 'bootstrap converges after installing one prerequisite'
assert_no_mutation 'a converged bootstrap rerun does not update APT metadata'

: >"$state_dir/apt"
run_bootstrap
assert_eq 0 "$bootstrap_status" 'a blank Ubuntu machine installs the complete prerequisite set'
installed_packages=$(sed -n 's/^apt-get <install> <-y> <--no-install-recommends> <--> <\([^>]*\)>$/\1/p' "$call_log" | LC_ALL=C sort)
assert_eq "$(printf 'ca-certificates\ngit')" "$installed_packages" \
  'bootstrap owns exactly ca-certificates and git'
assert_eq 1 "$(grep -c '^apt-get <update>$' "$call_log")" \
  'the complete prerequisite install updates APT metadata once'
case $(cat "$call_log") in
  *curl*|*'git <clone>'*|*systemctl*|*service*|*modprobe*|*ubuntu-drivers*)
    fail 'bootstrap invokes a download, clone, driver, or service action'
    ;;
esac

: >"$state_dir/apt"
FAKE_SUDO_MODE=denied run_bootstrap
assert_eq 2 "$bootstrap_status" 'denied sudo credential refresh is an actionable prerequisite error'
assert_contains "$bootstrap_output" \
  'manual command: sudo apt-get update && sudo apt-get install -y --no-install-recommends -- ca-certificates git' \
  'denied credential refresh prints the exact manual bootstrap command'
assert_no_apt_call 'denied privilege is detected before APT metadata mutation'

: >"$state_dir/apt"
SETUP_SUDO_COMMAND=true FAKE_SUDO_MODE=denied run_bootstrap
assert_eq 2 "$bootstrap_status" 'a true override cannot bypass denied sudo authorization'
assert_no_apt_call 'a true override cannot reach APT without sudo authorization'

: >"$state_dir/apt"
SETUP_SUDO_COMMAND=env FAKE_SUDO_MODE=denied run_bootstrap
assert_eq 2 "$bootstrap_status" 'an env override cannot bypass denied sudo authorization'
assert_no_apt_call 'an env override cannot reach APT without sudo authorization'

: >"$state_dir/apt"
mv "$fake_bin/sudo" "$fake_bin/sudo.saved"
BOOTSTRAP_PATH="$fake_bin:$safe_bin" run_bootstrap
assert_eq 2 "$bootstrap_status" 'absent sudo is an actionable prerequisite error'
assert_contains "$bootstrap_output" \
  'manual command: sudo apt-get update && sudo apt-get install -y --no-install-recommends -- ca-certificates git' \
  'absent sudo prints the exact manual bootstrap command'
assert_no_apt_call 'absent sudo is detected before APT metadata mutation'
mv "$fake_bin/sudo.saved" "$fake_bin/sudo"

: >"$state_dir/apt"
mv "$fake_bin/apt-get" "$fake_bin/apt-get.saved"
run_bootstrap
assert_eq 2 "$bootstrap_status" 'missing APT is rejected before mutation'
assert_no_mutation 'the complete mutation preflight checks APT availability'
mv "$fake_bin/apt-get.saved" "$fake_bin/apt-get"

: >"$state_dir/apt"
SETUP_OS_RELEASE="$debian_release" run_bootstrap
assert_eq 2 "$bootstrap_status" 'a non-Ubuntu platform is unsupported'
assert_contains "$bootstrap_output" 'unsupported platform: debian' 'the unsupported platform is identified'
assert_no_mutation 'unsupported platforms are rejected before mutation'

: >"$state_dir/apt"
FAKE_DPKG_FAILURE=git run_bootstrap
assert_eq 2 "$bootstrap_status" 'prerequisite inventory failure is a configuration error'
assert_no_mutation 'all prerequisite inventory completes before mutation'

printf 'ca-certificates\ngit\n' >"$state_dir/apt"
: >"$call_log"
set +e
wrapper_output=$(cd "$test_repo" && env \
  PATH="$fake_bin:/usr/bin:/bin" \
  SETUP_OS_RELEASE="$ubuntu_release" \
  FAKE_STATE_DIR="$state_dir" \
  FAKE_CALL_LOG="$call_log" \
  /bin/bash init/ubuntu.sh 2>&1)
wrapper_status=$?
set -e
assert_eq 0 "$wrapper_status" 'the legacy local initializer delegates to bootstrap'
assert_contains "$wrapper_output" \
  'init/ubuntu.sh is deprecated; delegating to bin/bootstrap' \
  'the legacy local initializer explains its deprecation'
assert_no_mutation 'the local initializer performs no legacy clone or update action'

: >"$call_log"
set +e
wrapper_output=$(cd "$test_repo" && env \
  PATH="$fake_bin:/usr/bin:/bin" \
  SETUP_OS_RELEASE="$tmp_dir/does-not-exist" \
  FAKE_STATE_DIR="$state_dir" \
  FAKE_CALL_LOG="$call_log" \
  /bin/bash init/ubuntu.sh unexpected 2>&1)
wrapper_status=$?
set -e
assert_eq 2 "$wrapper_status" 'the local initializer forwards invalid arguments to bootstrap'
assert_contains "$wrapper_output" 'usage:' 'forwarded invalid arguments print bootstrap usage'
assert_no_apt_call 'forwarded invalid arguments are rejected before APT mutation'

printf 'ok - bootstrap is minimal, preflighted, additive, and local\n'
