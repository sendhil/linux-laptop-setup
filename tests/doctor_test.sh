#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

test_repo="$tmp_dir/repository"
fake_bin="$tmp_dir/fake-bin"
host_bin="$tmp_dir/host-bin"
safe_bin="$tmp_dir/safe-bin"
call_log="$tmp_dir/calls.log"
policy_agent="$tmp_dir/policy-agent"
proc_root="$tmp_dir/proc"
empty_proc_root="$tmp_dir/empty-proc"
runtime_tmp="$tmp_dir/runtime-tmp"
mkdir -p "$test_repo" "$fake_bin" "$host_bin" "$safe_bin" \
  "$proc_root/123" "$empty_proc_root" "$runtime_tmp"
cp -R "$repo_dir"/. "$test_repo"/
printf 'runtime sentinel\n' >"$runtime_tmp/sentinel"

# Model a workplace Ubuntu host where externally managed Slack is installed.
# The doctor fixture must not let host applications change its result counts.
cat >"$host_bin/slack" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$host_bin/slack"

for command_name in awk cat dirname grep head sed sleep sort tr; do
  ln -s "$(command -v "$command_name")" "$safe_bin/$command_name"
done

cat >"$tmp_dir/run-with-deadline.py" <<'EOF'
import os
import signal
import subprocess
import sys

deadline = float(sys.argv[1])
process = subprocess.Popen(
    sys.argv[2:],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    start_new_session=True,
)
try:
    output, _ = process.communicate(timeout=deadline)
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGKILL)
    output, _ = process.communicate()
    sys.stdout.write(output)
    sys.exit(98)
sys.stdout.write(output)
sys.exit(process.returncode)
EOF

cat >"$policy_agent" <<'EOF'
#!/bin/bash
printf 'policy-agent' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
exit 97
EOF
chmod +x "$policy_agent"
ln -s "$policy_agent" "$proc_root/123/exe"

cat >"$tmp_dir/os-release" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
EOF

owned_commands='bash batcat blueman-applet brightnessctl bun bunx code curl difft direnv dust eza fc-match fzf gh git git-lfs go grim herdr http jq kitty lnav mako make nm-applet notify-send nvim obsidian opencode pi pipx pipewire playerctl pnpm python3 rg shellcheck slurp stow sway swayidle swaylock tmux tree unzip uv uvx waybar wezterm wireplumber wl-copy wl-paste wofi Xwayland ya yazi zoxide zsh'
external_commands='docker kubectl zoom'

make_success_command() {
  command_name=$1
  cat >"$fake_bin/$command_name" <<'EOF'
#!/bin/bash
printf '%s' "${0##*/}" >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
case ${0##*/} in
  fc-match)
    printf '%s\n' "${FAKE_FONT_FAMILY:-JetBrainsMono Nerd Font Mono}"
    exit 0
    ;;
  zsh)
    if [ "${FAKE_ZSH_IGNORE_TERM:-0}" -eq 1 ]; then
      trap '' TERM
      while :; do :; done
    fi
    if [ "${FAKE_ZSH_LARGE_OUTPUT:-0}" -eq 1 ]; then
      line_number=1
      while [ "$line_number" -le 20000 ]; do
        printf 'large diagnostic line %s\n' "$line_number"
        line_number=$((line_number + 1))
      done
    fi
    [ -z "${FAKE_ZSH_OUTPUT:-}" ] || printf '%b' "$FAKE_ZSH_OUTPUT"
    exit "${FAKE_ZSH_STATUS:-0}"
    ;;
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
[ "${1:-}" = -k ] || exit 64
[ "${2:-}" = 2 ] || exit 64
shift 2
duration=${1:-}
shift
case $duration:${1:-} in
  10:zsh)
    if [ "${FAKE_ZSH_IGNORE_TERM:-0}" -eq 1 ]; then
      "$@" &
      child=$!
      sleep 0.1
      kill -TERM "$child" 2>/dev/null || :
      sleep 0.1
      kill -0 "$child" 2>/dev/null || exit 65
      kill -KILL "$child" 2>/dev/null || :
      wait "$child" 2>/dev/null
      exit 137
    fi
    ;;
  10:*) : ;;
  5:nvidia-smi)
    [ "${FAKE_NVIDIA_TIMEOUT:-0}" -eq 0 ] || exit 124
    [ "${FAKE_NVIDIA_HARD_TIMEOUT:-0}" -eq 0 ] || exit 137
    ;;
  *) exit 64 ;;
esac
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

cat >"$fake_bin/readlink" <<'EOF'
#!/bin/bash
printf 'readlink' >>"$FAKE_CALL_LOG"
printf ' <%s>' "$@" >>"$FAKE_CALL_LOG"
printf '\n' >>"$FAKE_CALL_LOG"
[ "$#" -eq 2 ] || exit 97
[ "$1" = -f ] || exit 97
path=$2
if [ -L "$path" ]; then
  target=$(/usr/bin/readlink "$path") || exit 1
  case $target in
    /*) path=$target ;;
    *) path=${path%/*}/$target ;;
  esac
fi
directory=${path%/*}
base=${path##*/}
canonical_directory=$(CDPATH= cd -- "$directory" 2>/dev/null && pwd -P) || exit 1
printf '%s/%s\n' "$canonical_directory" "$base"
EOF

for forbidden in service modprobe pgrep ubuntu-drivers; do
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
  doctor_runner=(/bin/bash bin/doctor "${DOCTOR_PROFILE:-work}")
  if [ -n "${DOCTOR_OUTER_DEADLINE:-}" ]; then
    doctor_runner=(/usr/bin/python3 "$tmp_dir/run-with-deadline.py" \
      "$DOCTOR_OUTER_DEADLINE" "${doctor_runner[@]}")
  fi
  set +e
  doctor_output=$(cd "$test_repo" && env \
    PATH="$fake_bin:$safe_bin" \
    SETUP_OS_RELEASE="${SETUP_OS_RELEASE:-$tmp_dir/os-release}" \
    SETUP_POLICY_AGENT="${SETUP_POLICY_AGENT:-$policy_agent}" \
    SETUP_PROC_ROOT="${SETUP_PROC_ROOT:-$proc_root}" \
    TMPDIR="$runtime_tmp" \
    SWAYSOCK="${SWAYSOCK:-}" \
    XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}" \
    FAKE_CALL_LOG="$call_log" \
    FAKE_FONT_FAMILY="${FAKE_FONT_FAMILY:-JetBrainsMono Nerd Font Mono}" \
    FAKE_INACTIVE_SERVICE="${FAKE_INACTIVE_SERVICE:-}" \
    FAKE_LSMOD_OUTPUT="${FAKE_LSMOD_OUTPUT:-}" \
    FAKE_NVIDIA_HARD_TIMEOUT="${FAKE_NVIDIA_HARD_TIMEOUT:-0}" \
    FAKE_NVIDIA_STATUS="${FAKE_NVIDIA_STATUS:-0}" \
    FAKE_NVIDIA_TIMEOUT="${FAKE_NVIDIA_TIMEOUT:-0}" \
    FAKE_ZSH_LARGE_OUTPUT="${FAKE_ZSH_LARGE_OUTPUT:-0}" \
    FAKE_ZSH_IGNORE_TERM="${FAKE_ZSH_IGNORE_TERM:-0}" \
    FAKE_ZSH_OUTPUT="${FAKE_ZSH_OUTPUT:-}" \
    FAKE_ZSH_STATUS="${FAKE_ZSH_STATUS:-0}" \
    "${doctor_runner[@]}" 2>&1)
  doctor_status=$?
  set -e
}

run_doctor_args() {
  : >"$call_log"
  set +e
  doctor_output=$(cd "$test_repo" && env \
    PATH="$fake_bin:$safe_bin" \
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
assert_contains "$doctor_output" 'PASS command: go' 'owned Go command passes'
assert_contains "$doctor_output" 'PASS command: wofi' 'owned Wofi command passes'
assert_contains "$doctor_output" 'PASS command: wezterm' 'owned WezTerm command passes'
assert_contains "$doctor_output" 'PASS font: JetBrainsMono Nerd Font Mono' \
  'the exact WezTerm Nerd Font family passes'
case $doctor_output in
  *'command: fuzzel'*) fail 'doctor still checks unavailable Fuzzel' ;;
esac
assert_contains "$doctor_output" 'PASS command: fd (via fdfind)' 'Ubuntu fdfind satisfies the fd command check'
assert_contains "$doctor_output" 'WARN external command: slack' 'missing Slack is warning-only'
assert_contains "$doctor_output" 'SKIP Sway session checks: not running under Sway' 'non-Sway sessions skip service checks'
assert_contains "$doctor_output" 'PASS shell startup: bash' 'Bash startup is checked'
assert_contains "$doctor_output" 'PASS shell startup: zsh' 'Zsh startup is checked'
assert_contains "$doctor_output" 'Summary: PASS ' 'doctor prints result accounting'
assert_contains "$doctor_output" ' WARN 1 SKIP 1 FAIL 0' 'warnings and skips do not count as failures'

FAKE_FONT_FAMILY='DejaVu Sans Mono' run_doctor
assert_eq 1 "$doctor_status" 'a fallback font fails the owned WezTerm font check'
assert_contains "$doctor_output" 'FAIL font: JetBrainsMono Nerd Font Mono' \
  'the missing exact WezTerm font family is identified'
assert_contains "$(cat "$call_log")" 'timeout <-k> <2> <10> <bash> <-lic> <exit>' 'Bash startup has a two-second hard-kill grace period'
assert_contains "$(cat "$call_log")" 'timeout <-k> <2> <10> <zsh> <-lic> <exit>' 'Zsh startup has a two-second hard-kill grace period'
case $(cat "$call_log") in
  *systemctl*|*readlink*) fail 'non-Sway sessions do not query user services or the policy agent' ;;
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

FAKE_ZSH_STATUS=7 FAKE_ZSH_OUTPUT=$'startup problem\nsecond line\n' run_doctor
assert_eq 1 "$doctor_status" 'a failed bounded shell startup is owned drift'
assert_contains "$doctor_output" 'FAIL shell startup: zsh (status 7)' 'failed Zsh startup includes its status'
assert_contains "$doctor_output" $'  startup problem\n  second line' 'shell startup diagnostics are indented'

diagnostic_lines='line 1 unsafe\033[31m-red\033[0m\n'
line_number=2
while [ "$line_number" -le 25 ]; do
  diagnostic_lines="${diagnostic_lines}line $line_number\n"
  line_number=$((line_number + 1))
done
FAKE_ZSH_STATUS=7 FAKE_ZSH_OUTPUT="$diagnostic_lines" run_doctor
assert_eq 1 "$doctor_status" 'verbose shell startup failure remains owned drift'
assert_contains "$doctor_output" '  line 1 unsafe-red' 'shell diagnostics strip terminal styling sequences'
assert_contains "$doctor_output" '  line 20' 'shell diagnostics retain the twentieth line'
case $doctor_output in
  *'line 21'*|*$'\033'*) fail 'shell diagnostics are bounded and strip terminal control bytes' ;;
esac

FAKE_ZSH_STATUS=124 FAKE_ZSH_OUTPUT='partial output\n' run_doctor
assert_eq 1 "$doctor_status" 'a timed-out shell startup is owned drift'
assert_contains "$doctor_output" 'FAIL shell startup: zsh (timed out after 10s)' 'shell timeout is distinguished from other failures'
case $doctor_output in
  *'partial output'*) fail 'timeout output does not obscure the bounded-time diagnosis' ;;
esac

DOCTOR_OUTER_DEADLINE=3 FAKE_ZSH_IGNORE_TERM=1 run_doctor
if [ "$doctor_status" -eq 98 ]; then
  fail 'the independent outer safety deadline killed the doctor'
fi
assert_eq 1 "$doctor_status" 'a TERM-ignoring shell is hard-killed before the outer deadline'
assert_contains "$doctor_output" 'FAIL shell startup: zsh (timed out after 10s)' 'status 137 is reported as a shell timeout'

runtime_before=$(find "$runtime_tmp" -type f -print | LC_ALL=C sort)
FAKE_ZSH_STATUS=7 FAKE_ZSH_LARGE_OUTPUT=1 run_doctor
assert_eq 1 "$doctor_status" 'large shell diagnostics preserve the command status'
assert_contains "$doctor_output" 'FAIL shell startup: zsh (status 7)' 'bounded capture preserves a nonzero producer status'
assert_contains "$doctor_output" '  large diagnostic line 20' 'bounded capture retains useful leading output'
case $doctor_output in
  *'large diagnostic line 21'*) fail 'large shell diagnostics remain bounded to twenty displayed lines' ;;
esac
assert_eq "$runtime_before" "$(find "$runtime_tmp" -type f -print | LC_ALL=C sort)" 'bounded shell capture creates no temporary files'
doctor_source=$(cat "$test_repo/bin/doctor")
assert_contains "$doctor_source" 'head -c 4096' 'shell output is bounded during capture'
assert_contains "$doctor_source" 'cat >/dev/null' 'shell output beyond the capture limit is drained'

XDG_CURRENT_DESKTOP=noswaydesktop run_doctor
assert_eq 0 "$doctor_status" 'a desktop name merely containing sway is not a Sway session'
assert_contains "$doctor_output" 'SKIP Sway session checks: not running under Sway' 'non-token desktop name skips Sway checks'
case $(cat "$call_log") in
  *systemctl*|*readlink*) fail 'a non-token desktop name does not trigger Sway checks' ;;
esac

SWAYSOCK="$tmp_dir/sway.sock" run_doctor
assert_eq 0 "$doctor_status" 'an active Sway session with healthy user services succeeds'
for service_name in pipewire.service wireplumber.service xdg-desktop-portal.service xdg-desktop-portal-wlr.service; do
  assert_contains "$doctor_output" "PASS user service: $service_name" "healthy $service_name is reported"
  assert_contains "$(cat "$call_log")" \
    "systemctl <--user> <is-active> <--quiet> <$service_name>" \
    "$service_name is queried read-only"
done
assert_contains "$doctor_output" "PASS policy agent: $policy_agent (running)" 'the executable running policy agent passes'
assert_contains "$(cat "$call_log")" "readlink <-f> <$policy_agent>" 'policy agent executable is canonicalized read-only'
assert_contains "$(cat "$call_log")" "readlink <-f> <$proc_root/123/exe>" 'proc executable identity is canonicalized read-only'
case $(cat "$call_log") in
  *pgrep*) fail 'policy agent verification never performs a command-line regex search' ;;
esac
if grep '^policy-agent\([[:space:]]\|$\)' "$call_log" >/dev/null 2>&1; then
  fail 'doctor never starts the policy agent executable'
fi

XDG_CURRENT_DESKTOP=' GNOME : SwAy ' run_doctor
assert_eq 0 "$doctor_status" 'a case-insensitive colon-delimited Sway token enables session checks'
assert_contains "$doctor_output" 'PASS user service: pipewire.service' 'trimmed exact Sway desktop token triggers service checks'

SWAYSOCK="$tmp_dir/sway.sock" SETUP_POLICY_AGENT="$tmp_dir/missing-policy-agent" run_doctor
assert_eq 1 "$doctor_status" 'a missing Sway policy agent executable fails the doctor'
assert_contains "$doctor_output" "FAIL policy agent: not executable: $tmp_dir/missing-policy-agent" 'missing policy agent executable is identified'

SWAYSOCK="$tmp_dir/sway.sock" SETUP_PROC_ROOT="$empty_proc_root" run_doctor
assert_eq 1 "$doctor_status" 'a non-running Sway policy agent fails the doctor'
assert_contains "$doctor_output" "FAIL policy agent: not running: $policy_agent" 'non-running policy agent is identified'

SWAYSOCK="$tmp_dir/sway.sock" SETUP_PROC_ROOT="$tmp_dir/missing-proc" run_doctor
assert_eq 1 "$doctor_status" 'an unavailable proc tree fails policy-agent verification'
assert_contains "$doctor_output" "FAIL policy agent: cannot verify process state: $tmp_dir/missing-proc unavailable" 'unavailable proc tree is identified'

SETUP_POLICY_AGENT=relative/policy-agent run_doctor
assert_eq 2 "$doctor_status" 'a relative injected policy agent path is invalid configuration'
assert_contains "$doctor_output" 'invalid policy agent path: relative/policy-agent' 'relative policy agent path is identified'
assert_eq '' "$(cat "$call_log")" 'relative policy agent path is rejected before operational checks'

SETUP_POLICY_AGENT=$'/tmp/policy-agent\nbad' run_doctor
assert_eq 2 "$doctor_status" 'a policy agent path containing control characters is invalid configuration'
assert_contains "$doctor_output" 'invalid policy agent path' 'unsafe policy agent path is rejected safely'
assert_eq '' "$(cat "$call_log")" 'unsafe policy agent path is rejected before operational checks'

SETUP_PROC_ROOT=relative/proc run_doctor
assert_eq 2 "$doctor_status" 'a relative injected proc root is invalid configuration'
assert_contains "$doctor_output" 'invalid proc root: relative/proc' 'relative proc root is identified'
assert_eq '' "$(cat "$call_log")" 'relative proc root is rejected before operational checks'

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

cat >"$fake_bin/nvidia-smi" <<'EOF'
#!/bin/bash
printf 'nvidia-smi\n' >>"$FAKE_CALL_LOG"
exit "${FAKE_NVIDIA_STATUS:-0}"
EOF
chmod +x "$fake_bin/nvidia-smi"
run_doctor
assert_eq 0 "$doctor_status" 'proprietary NVIDIA detection remains warning-only'
assert_contains "$doctor_output" 'WARN PROPRIETARY NVIDIA DRIVER DETECTED' 'successful nvidia-smi detection is prominent'
assert_contains "$(cat "$call_log")" 'timeout <-k> <2> <5> <nvidia-smi>' 'nvidia-smi has a two-second hard-kill grace period'

FAKE_NVIDIA_STATUS=9 run_doctor
assert_eq 0 "$doctor_status" 'an unusable nvidia-smi command does not fail the doctor'
case $doctor_output in
  *'PROPRIETARY NVIDIA DRIVER DETECTED'*) fail 'a nonzero nvidia-smi command is not evidence of a loaded proprietary driver' ;;
esac

FAKE_NVIDIA_TIMEOUT=1 run_doctor
assert_eq 0 "$doctor_status" 'a timed-out nvidia-smi probe does not fail the doctor'
case $doctor_output in
  *'PROPRIETARY NVIDIA DRIVER DETECTED'*) fail 'a timed-out nvidia-smi probe falls back without becoming evidence itself' ;;
esac
assert_contains "$(cat "$call_log")" 'lsmod' 'a timed-out nvidia-smi probe falls back to loaded modules'

FAKE_NVIDIA_HARD_TIMEOUT=1 run_doctor
assert_eq 0 "$doctor_status" 'a hard-killed nvidia-smi probe does not fail the doctor'
case $doctor_output in
  *'PROPRIETARY NVIDIA DRIVER DETECTED'*) fail 'a hard-killed nvidia-smi probe falls back without becoming evidence itself' ;;
esac
assert_contains "$(cat "$call_log")" 'lsmod' 'status 137 from nvidia-smi falls back to loaded modules'

FAKE_NVIDIA_STATUS=9 FAKE_LSMOD_OUTPUT=$'Module Size Used by\nnvidia_drm 123 0' run_doctor
assert_eq 0 "$doctor_status" 'a loaded proprietary NVIDIA module remains warning-only'
assert_contains "$doctor_output" 'WARN PROPRIETARY NVIDIA DRIVER DETECTED' 'lsmod is used after an unusable nvidia-smi command'

FAKE_NVIDIA_STATUS=9 FAKE_LSMOD_OUTPUT=$'Module Size Used by\nnvidia 123 0' run_doctor
assert_eq 0 "$doctor_status" 'the exact nvidia module remains warning-only'
assert_contains "$doctor_output" 'WARN PROPRIETARY NVIDIA DRIVER DETECTED' 'the exact nvidia module token is detected'

for unrelated_module in notnvidia nvidia_ nvidiafb nvidialies; do
  FAKE_NVIDIA_STATUS=9 FAKE_LSMOD_OUTPUT="Module Size Used by
$unrelated_module 123 0" run_doctor
  assert_eq 0 "$doctor_status" "the $unrelated_module module does not fail the doctor"
  case $doctor_output in
    *'PROPRIETARY NVIDIA DRIVER DETECTED'*) fail "module detection excludes $unrelated_module" ;;
  esac
done

printf 'ok - doctor is manifest-scoped, bounded, read-only, and session-aware\n'
