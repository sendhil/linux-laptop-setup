#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

assert_not_contains() {
  case $1 in
    *"$2"*) fail "$3 (unexpected '$2')" ;;
    *) : ;;
  esac
}

cd "$repo_dir"
[ -x bin/setup-work-laptop ] || fail 'work-laptop coordinator is executable'

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_repo="$tmp_dir/linux setup"
fake_dotfiles="$tmp_dir/dotfiles checkout"
fake_home="$tmp_dir/home"
fake_bin="$tmp_dir/fake-bin"
log="$tmp_dir/actions.log"
mkdir -p "$fake_repo/bin" "$fake_repo/lib" "$fake_repo/profiles" \
  "$fake_repo/docs" "$fake_dotfiles/scripts" "$fake_home" "$fake_bin"
cp bin/setup-work-laptop "$fake_repo/bin/setup-work-laptop"
cp lib/common.sh lib/platform.sh "$fake_repo/lib/"
: >"$fake_repo/profiles/work.apt.txt"
: >"$fake_repo/profiles/work.external.txt"
printf '# checklist\n' >"$fake_repo/docs/first-sway-login.md"
printf 'all:\n' >"$fake_dotfiles/Makefile"
printf 'ID=ubuntu\nVERSION_ID="22.04"\nVERSION_CODENAME=jammy\n' >"$tmp_dir/os-release"
: >"$tmp_dir/modules"

cat >"$fake_repo/bin/fake-component" <<'EOF'
#!/bin/bash
name=${0##*/}
printf '%s %s\n' "$name" "$*" >>"$SETUP_TEST_LOG"
if [ "${SETUP_FAIL_STAGE:-}" = "$name" ]; then
  exit "${SETUP_FAIL_STATUS:-1}"
fi
EOF
chmod +x "$fake_repo/bin/fake-component"
for component in bootstrap install-wezterm apply install-work-tools doctor install-sway-nvidia-session; do
  ln -s fake-component "$fake_repo/bin/$component"
done

cat >"$fake_dotfiles/scripts/setup-local-laptop.sh" <<'EOF'
#!/bin/bash
printf 'setup-local-laptop %s\n' "$*" >>"$SETUP_TEST_LOG"
mkdir -p "$HOME/.config/sway/local.d" "$HOME/.config/wezterm"
cat >"$HOME/.config/sway/local.d/laptop.conf" <<'PROFILE'
# Managed by dotfiles scripts/setup-local-laptop.sh.
input "1:1:built_in_keyboard" {
    xkb_options altwin:swap_lalt_lwin
}
input "1:1:built_in_touchpad" {
    tap enabled
    tap_button_map lrm
    natural_scroll enabled
}
PROFILE
cat >"$HOME/.config/wezterm/local.lua" <<'PROFILE'
# Managed by dotfiles scripts/setup-local-laptop.sh.
return {
  font_size = 17,
}
PROFILE
EOF
chmod +x "$fake_dotfiles/scripts/setup-local-laptop.sh"

cat >"$fake_bin/id" <<'EOF'
#!/bin/bash
if [ "${1:-}" = -u ]; then
  printf '%s\n' "${SETUP_TEST_UID:-1000}"
else
  /usr/bin/id "$@"
fi
EOF
cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
case ${1:-} in
  --print-architecture) printf '%s\n' "${SETUP_TEST_ARCH:-amd64}" ;;
  --audit)
    [ -z "${SETUP_TEST_DPKG_AUDIT:-}" ] || printf '%s\n' "$SETUP_TEST_DPKG_AUDIT"
    exit "${SETUP_TEST_DPKG_STATUS:-0}"
    ;;
  *) exit 2 ;;
esac
EOF
cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo %s\n' "$*" >>"$SETUP_TEST_LOG"
if [ "${1:-}" = -v ]; then
  exit "${SETUP_TEST_SUDO_STATUS:-0}"
fi
exec "$@"
EOF
cat >"$fake_bin/make" <<'EOF'
#!/bin/bash
printf 'make %s\n' "$*" >>"$SETUP_TEST_LOG"
case " $* " in
  *' stow-ubuntu '*)
    mkdir -p "$HOME/.config/sway"
    printf '# fake Sway config\n' >"$HOME/.config/sway/config"
    ;;
esac
EOF
cat >"$fake_bin/sway" <<'EOF'
#!/bin/bash
printf 'sway %s\n' "$*" >>"$SETUP_TEST_LOG"
exit "${SETUP_TEST_SWAY_STATUS:-0}"
EOF
chmod +x "$fake_bin"/*

run_setup() {
  env HOME="$fake_home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="$tmp_dir/os-release" \
    SETUP_PROC_MODULES="$tmp_dir/modules" \
    SETUP_TEST_LOG="$log" \
    "$@" \
    bash "$fake_repo/bin/setup-work-laptop" work "$fake_dotfiles"
}

: >"$log"
set +e
invalid_output=$(bash "$fake_repo/bin/setup-work-laptop" work 2>&1)
invalid_status=$?
set -e
assert_eq 2 "$invalid_status" 'coordinator rejects missing dotfiles checkout argument'
assert_contains "$invalid_output" 'usage:' 'coordinator invalid input prints usage'
[ ! -s "$log" ] || fail 'invalid coordinator input invoked a component'

: >"$log"
set +e
root_output=$(run_setup SETUP_TEST_UID=0 2>&1)
root_status=$?
set -e
assert_eq 2 "$root_status" 'coordinator rejects root invocation'
assert_contains "$root_output" 'normal user' 'root rejection is actionable'
[ ! -s "$log" ] || fail 'root coordinator invocation reached a delegated component'

: >"$log"
set +e
broken_output=$(run_setup SETUP_TEST_DPKG_AUDIT='winehq-stable is unpacked but unconfigured' 2>&1)
broken_status=$?
set -e
assert_eq 2 "$broken_status" 'coordinator rejects unhealthy dpkg state'
assert_contains "$broken_output" 'sudo bin/audit-wine' 'dpkg rejection points to the read-only Wine diagnostic'
if grep -Eq 'bootstrap|install-wezterm|apply|install-work-tools|make|doctor' "$log"; then
  fail 'coordinator mutated after detecting unhealthy dpkg state'
fi

: >"$log"
rm -rf "$fake_home/.config"
first_output=$(run_setup 2>&1)
assert_contains "$first_output" 'select Sway in GDM' 'standard first pass prints exact Sway login guidance'
assert_contains "$first_output" 'rerun:' 'first pass labels the resumable command'
assert_contains "$first_output" 'setup-work-laptop' 'first pass prints the coordinator path'
first_log=$(cat "$log")
for action in \
  'sudo -v' \
  'sudo dpkg --audit' \
  'bootstrap ' \
  'install-wezterm ' \
  'apply work' \
  'install-work-tools ' \
  "make -C $fake_dotfiles preflight-ubuntu" \
  "make -C $fake_dotfiles stow-ubuntu" \
  "sway --validate -c $fake_home/.config/sway/config" \
  'doctor work'; do
  assert_contains "$first_log" "$action" "standard first pass invokes $action"
done
assert_not_contains "$first_log" 'setup-local-laptop' \
  'GNOME first pass must not configure a live Sway keyboard'
assert_not_contains "$first_log" 'install-sway-nvidia-session' \
  'standard graphics path must not install the NVIDIA test session'

: >"$log"
printf 'nvidia 123 0 - Live 0x0\n' >"$tmp_dir/modules"
nvidia_output=$(run_setup 2>&1)
assert_contains "$nvidia_output" 'Sway (NVIDIA test)' \
  'NVIDIA first pass identifies the separate GDM test session'
assert_contains "$(cat "$log")" 'install-sway-nvidia-session ' \
  'NVIDIA first pass installs the separate session'
printf '' >"$tmp_dir/modules"

: >"$log"
rm -rf "$fake_home/.config/sway/local.d" "$fake_home/.config/wezterm"
sway_output=$(run_setup SWAYSOCK="$tmp_dir/sway.sock" XDG_CURRENT_DESKTOP=' GNOME : SwAy ')
assert_contains "$sway_output" 'setup complete' 'Sway pass reports completion'
assert_contains "$sway_output" "$fake_repo/docs/first-sway-login.md" \
  'Sway pass points to the physical checklist'
assert_contains "$(cat "$log")" 'setup-local-laptop --font-size 17' \
  'Sway pass creates the approved laptop-local profile'

: >"$log"
run_setup SWAYSOCK="$tmp_dir/sway.sock" >/dev/null
assert_not_contains "$(cat "$log")" 'setup-local-laptop' \
  'converged Sway rerun preserves the managed local profile'

: >"$log"
printf '# Managed by dotfiles scripts/setup-local-laptop.sh.\n' >"$fake_home/.config/sway/local.d/laptop.conf"
run_setup SWAYSOCK="$tmp_dir/sway.sock" >/dev/null
assert_contains "$(cat "$log")" 'setup-local-laptop --font-size 17' \
  'legacy managed profile is upgraded with current laptop-local defaults'

: >"$log"
set +e
failure_output=$(run_setup SETUP_FAIL_STAGE=apply SETUP_FAIL_STATUS=1 2>&1)
failure_status=$?
set -e
assert_eq 1 "$failure_status" 'coordinator propagates delegated operational failure'
assert_contains "$failure_output" 'rerun:' 'delegated failure prints the coordinator rerun command'
assert_not_contains "$(cat "$log")" 'make ' 'coordinator stops after package apply failure'

: >"$log"
set +e
failure_output=$(run_setup SETUP_FAIL_STAGE=install-work-tools SETUP_FAIL_STATUS=1 2>&1)
failure_status=$?
set -e
assert_eq 1 "$failure_status" 'coordinator propagates work-tool installation failure'
assert_contains "$failure_output" 'rerun:' 'work-tool failure prints the coordinator rerun command'
assert_not_contains "$(cat "$log")" 'make ' 'coordinator stops after work-tool installation failure'

printf 'ok - resumable two-pass work-laptop coordinator\n'
