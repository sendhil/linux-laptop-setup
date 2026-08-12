#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

test_repo="$tmp_dir/repository"
fake_bin="$tmp_dir/fake-bin"
call_log="$tmp_dir/calls.log"
mkdir -p "$test_repo" "$fake_bin"
cp -R "$repo_dir"/. "$test_repo"/

cat >"$tmp_dir/os-release" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
EOF

owned_commands='bash batcat blueman-applet brightnessctl curl direnv fuzzel fzf git grim jq kitty mako make nm-applet notify-send nvim pipx pipewire playerctl python3 rg shellcheck slurp stow sway swayidle swaylock tmux tree waybar wireplumber wl-copy wl-paste Xwayland zoxide zsh'
external_commands='docker kubectl zoom'

make_success_command() {
  command_name=$1
  cat >"$fake_bin/$command_name" <<'EOF'
#!/bin/bash
printf '%s' "${0##*/}" >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
case ${0##*/} in
  zsh) [ "${FAKE_ZSH_FAILURE:-0}" -eq 0 ] ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$fake_bin/$command_name"
}

for command_name in $owned_commands $external_commands fdfind; do
  make_success_command "$command_name"
done

cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
printf 'dpkg' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
[ "${1:-}" = --print-architecture ] || exit 2
printf 'amd64\n'
EOF

cat >"$fake_bin/timeout" <<'EOF'
#!/bin/bash
printf 'timeout' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
[ "${1:-}" = 10 ] || exit 64
shift
"$@"
EOF

cat >"$fake_bin/systemctl" <<'EOF'
#!/bin/bash
printf 'systemctl' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
[ "$#" -eq 4 ] || exit 97
[ "$1" = --user ] || exit 97
[ "$2" = is-active ] || exit 97
[ "$3" = --quiet ] || exit 97
[ "$4" != "${FAKE_INACTIVE_SERVICE:-}" ]
EOF

cat >"$fake_bin/lsmod" <<'EOF'
#!/bin/bash
printf 'lsmod\n' >>"$FAKE_CALL_LOG"
printf '%s\n' "${FAKE_LSMOD_OUTPUT:-Module Size Used by}"
EOF

for forbidden in service modprobe ubuntu-drivers; do
  cat >"$fake_bin/$forbidden" <<EOF
#!/bin/bash
printf '$forbidden' >>"\$FAKE_CALL_LOG"
printf ' <%s>' "\$@" >>"\$FAKE_CALL_LOG"
printf '\n' >>"\$FAKE_CALL_LOG"
exit 97
EOF
done
chmod +x "$fake_bin"/*

run_doctor() {
  : >"$call_log"
  set +e
  doctor_output=$(cd "$test_repo" && env \
    PATH="$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="${SETUP_OS_RELEASE:-$tmp_dir/os-release}" \
    SWAYSOCK="${SWAYSOCK:-}" \
    XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}" \
    FAKE_CALL_LOG="$call_log" \
    FAKE_INACTIVE_SERVICE="${FAKE_INACTIVE_SERVICE:-}" \
    FAKE_LSMOD_OUTPUT="${FAKE_LSMOD_OUTPUT:-}" \
    FAKE_ZSH_FAILURE="${FAKE_ZSH_FAILURE:-0}" \
    /bin/bash bin/doctor "${DOCTOR_PROFILE:-work}" 2>&1)
  doctor_status=$?
  set -e
}

run_doctor_args() {
  : >"$call_log"
  set +e
  doctor_output=$(cd "$test_repo" && env \
    PATH="$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="$tmp_dir/does-not-exist" \
    FAKE_CALL_LOG="$call_log" \
    /bin/bash bin/doctor "$@" 2>&1)
  doctor_status=$?
  set -e
}

run_doctor_args
assert_eq 2 "$doctor_status" 'doctor requires exactly one profile argument'
assert_contains "$doctor_output" 'usage: bin/doctor PROFILE' 'invalid arguments print usage'
assert_eq '' "$(cat "$call_log")" 'argument validation happens before operational checks'

run_doctor_args work extra
assert_eq 2 "$doctor_status" 'doctor rejects extra arguments'
assert_eq '' "$(cat "$call_log")" 'extra arguments are rejected before operational checks'

DOCTOR_PROFILE=missing run_doctor
assert_eq 2 "$doctor_status" 'doctor rejects an unknown profile'
assert_contains "$doctor_output" 'unknown profile: missing' 'unknown profile is identified'
assert_eq '' "$(cat "$call_log")" 'profile validation happens before operational checks'

printf 'unsafe;entry\n' >>"$test_repo/manifests/apt-common.txt"
run_doctor
assert_eq 2 "$doctor_status" 'doctor rejects an invalid owned manifest'
assert_eq '' "$(cat "$call_log")" 'all manifests validate before operational checks'
sed -i.bak '$d' "$test_repo/manifests/apt-common.txt"
rm "$test_repo/manifests/apt-common.txt.bak"

run_doctor
assert_eq 0 "$doctor_status" 'healthy owned commands succeed despite missing external software'
assert_contains "$doctor_output" 'PASS command: nvim' 'owned Neovim command passes'
assert_contains "$doctor_output" 'PASS command: fd (via fdfind)' 'Ubuntu fdfind satisfies the fd command check'
assert_contains "$doctor_output" 'WARN external command: slack' 'missing Slack is warning-only'
assert_contains "$doctor_output" 'SKIP Sway session checks: not running under Sway' 'non-Sway sessions skip service checks'
assert_contains "$doctor_output" 'PASS shell startup: bash' 'Bash startup is checked'
assert_contains "$doctor_output" 'PASS shell startup: zsh' 'Zsh startup is checked'
assert_contains "$doctor_output" 'Summary: PASS ' 'doctor prints result accounting'
assert_contains "$doctor_output" ' WARN 1 SKIP 1 FAIL 0' 'warnings and skips do not count as failures'
assert_contains "$(cat "$call_log")" 'timeout <10> <bash> <-lic> <exit>' 'Bash startup is bounded to ten seconds'
assert_contains "$(cat "$call_log")" 'timeout <10> <zsh> <-lic> <exit>' 'Zsh startup is bounded to ten seconds'
case $(cat "$call_log") in
  *systemctl*) fail 'non-Sway sessions do not query user services' ;;
esac

mv "$fake_bin/nvim" "$fake_bin/nvim.saved"
run_doctor
assert_eq 1 "$doctor_status" 'a missing owned command fails the doctor'
assert_contains "$doctor_output" 'FAIL command: nvim' 'missing nvim is reported as an owned failure'
assert_contains "$doctor_output" 'FAIL 1' 'missing nvim increments failure accounting'
mv "$fake_bin/nvim.saved" "$fake_bin/nvim"

grep -v '^neovim ' "$test_repo/manifests/apt-common.txt" >"$test_repo/manifests/apt-common.txt.filtered"
mv "$test_repo/manifests/apt-common.txt.filtered" "$test_repo/manifests/apt-common.txt"
mv "$fake_bin/nvim" "$fake_bin/nvim.saved"
run_doctor
assert_eq 0 "$doctor_status" 'doctor checks only commands owned by the active manifests'
case $doctor_output in
  *'command: nvim'*) fail 'an undeclared Neovim package does not create a doctor check' ;;
esac
mv "$fake_bin/nvim.saved" "$fake_bin/nvim"
printf 'neovim 0.9.0\n' >>"$test_repo/manifests/apt-common.txt"

FAKE_ZSH_FAILURE=1 run_doctor
assert_eq 1 "$doctor_status" 'a failed bounded shell startup is owned drift'
assert_contains "$doctor_output" 'FAIL shell startup: zsh' 'failed Zsh startup is identified'

SWAYSOCK="$tmp_dir/sway.sock" run_doctor
assert_eq 0 "$doctor_status" 'an active Sway session with healthy user services succeeds'
for service_name in pipewire.service wireplumber.service xdg-desktop-portal.service xdg-desktop-portal-wlr.service; do
  assert_contains "$doctor_output" "PASS user service: $service_name" "healthy $service_name is reported"
  assert_contains "$(cat "$call_log")" \
    "systemctl <--user> <is-active> <--quiet> <$service_name>" \
    "$service_name is queried read-only"
done

SWAYSOCK="$tmp_dir/sway.sock" FAKE_INACTIVE_SERVICE=xdg-desktop-portal-wlr.service run_doctor
assert_eq 1 "$doctor_status" 'an inactive Sway portal fails the doctor'
assert_contains "$doctor_output" 'FAIL user service: xdg-desktop-portal-wlr.service' 'the inactive portal is identified'
case $(cat "$call_log") in
  *'<enable>'*|*'<disable>'*|*'<start>'*|*'<stop>'*|*'<restart>'*|*'<reload>'*|*modprobe*|*ubuntu-drivers*)
    fail 'doctor never mutates services or drivers'
    ;;
esac
if grep '^service\([[:space:]]\|$\)' "$call_log" >/dev/null 2>&1; then
  fail 'doctor never invokes the mutating service command'
fi

make_success_command nvidia-smi
run_doctor
assert_eq 0 "$doctor_status" 'proprietary NVIDIA detection remains warning-only'
assert_contains "$doctor_output" 'WARN PROPRIETARY NVIDIA DRIVER DETECTED' 'proprietary NVIDIA warning is prominent'
rm "$fake_bin/nvidia-smi"

FAKE_LSMOD_OUTPUT=$'Module Size Used by\nnvidia 123 0' run_doctor
assert_eq 0 "$doctor_status" 'a loaded proprietary NVIDIA module remains warning-only'
assert_contains "$doctor_output" 'WARN PROPRIETARY NVIDIA DRIVER DETECTED' 'loaded NVIDIA module is detected read-only'

printf 'ok - doctor is manifest-scoped, bounded, read-only, and session-aware\n'
