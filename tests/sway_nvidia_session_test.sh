#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

cd "$repo_dir"
script=bin/install-sway-nvidia-session
session_asset=assets/sway-nvidia.desktop
[ -x "$script" ] || fail 'Sway NVIDIA session installer is executable'
[ -r "$session_asset" ] || fail 'Sway NVIDIA desktop entry is tracked and readable'

set +e
invalid_output=$(SETUP_OS_RELEASE=/does/not/exist bash "$script" unexpected 2>&1)
invalid_status=$?
set -e
assert_eq 2 "$invalid_status" 'installer accepts exactly zero arguments'
assert_contains "$invalid_output" 'usage: bin/install-sway-nvidia-session' \
  'invalid arguments print usage before platform inspection'

script_text=$(cat "$script")
for required_text in \
  'session_dir=/usr/share/wayland-sessions' \
  'session_target=$session_dir/sway-nvidia.desktop' \
  'session_source=$repo_dir/assets/sway-nvidia.desktop' \
  '/usr/bin/sway --unsupported-gpu --validate -c "$sway_config"' \
  "grep -Eq '^nvidia(_[^[:space:]]*)?[[:space:]]' /proc/modules" \
  'refusing to overwrite differing session file' \
  'sudo -v' \
  'sudo install -o root -g root -m 0644 --'; do
  assert_contains "$script_text" "$required_text" "installer contains required contract: $required_text"
done

session_text=$(cat "$session_asset")
for required_text in \
  '[Desktop Entry]' \
  'Name=Sway (NVIDIA test)' \
  'Exec=/usr/bin/sway --unsupported-gpu' \
  'TryExec=/usr/bin/sway' \
  'Type=Application' \
  'DesktopNames=sway;'; do
  assert_contains "$session_text" "$required_text" "session asset contains required field: $required_text"
done
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$session_asset" || fail 'tracked Sway NVIDIA desktop entry validates'
fi

case $script_text in
  *'/usr/share/wayland-sessions/sway.desktop'*)
    fail 'installer targets Ubuntu standard Sway session'
    ;;
  *modprobe*|*ubuntu-drivers*|*apt-get*|*systemctl*|*service*)
    fail 'installer changes drivers, packages, or services'
    ;;
esac

conflict_line=$(grep -n 'refusing to overwrite differing session file' "$script" | cut -d: -f1)
sudo_line=$(grep -n '^if ! sudo -v' "$script" | cut -d: -f1)
[ "$conflict_line" -lt "$sudo_line" ] || \
  fail 'installer checks target conflicts before requesting sudo'

printf 'ok - Sway NVIDIA session installer is additive, guarded, and reproducible\n'
