#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

cd "$repo_dir"

script=bin/install-wezterm
source_asset=assets/wezterm-fury.list
[ -x "$script" ] || fail 'WezTerm installer is executable'
[ -r "$source_asset" ] || fail 'official WezTerm APT source asset is tracked'

set +e
invalid_output=$(SETUP_OS_RELEASE=/does/not/exist bash "$script" unexpected 2>&1)
invalid_status=$?
set -e
assert_eq 2 "$invalid_status" 'WezTerm installer accepts exactly zero arguments'
assert_contains "$invalid_output" 'usage: bin/install-wezterm' \
  'invalid arguments print usage before platform inspection'

assert_eq 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
  "$(cat "$source_asset")" 'tracked source uses the official signed WezTerm repository'

script_text=$(cat "$script")
for required_text in \
  'https://apt.fury.io/wez/gpg.key' \
  'EAB6DB20B1C8C3A5DB4B6AD08FC75FD3EB56E90B' \
  'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.tar.xz' \
  '0227b220360a6f819b9ead92343e8112b34733054782561af50cfba1e8afab63' \
  '/usr/share/keyrings/wezterm-fury.gpg' \
  '/etc/apt/sources.list.d/wezterm.list' \
  'JetBrainsMono Nerd Font Mono' \
  "trap 'exit 143' TERM" \
  'sudo -v' \
  'sudo apt-get update' \
  'sudo apt-get install -y --no-install-recommends -- wezterm'; do
  assert_contains "$script_text" "$required_text" "installer contains required contract: $required_text"
done

case $script_text in
  *apt-key*) fail 'installer uses retired apt-key' ;;
esac
if grep -E 'curl[^|]*\|.*([[:space:]]|^)(ba)?sh([[:space:]]|$)' "$script" >/dev/null; then
  fail 'installer pipes downloaded content to a shell'
fi

source_conflict_line=$(grep -n -m1 'refusing to overwrite differing APT source' "$script" | cut -d: -f1)
key_conflict_line=$(grep -n -m1 'refusing to overwrite differing keyring' "$script" | cut -d: -f1)
font_parent_line=$(grep -n -m1 'font directory parent is not writable' "$script" | cut -d: -f1)
duplicate_font_line=$(grep -n -m1 'duplicate font archive member' "$script" | cut -d: -f1)
sudo_line=$(grep -n 'if ! sudo -v' "$script" | cut -d: -f1)
[ "$source_conflict_line" -lt "$sudo_line" ] || \
  fail 'APT source conflicts are checked before requesting sudo'
[ "$key_conflict_line" -lt "$sudo_line" ] || \
  fail 'keyring conflicts are checked before requesting sudo'
[ "$font_parent_line" -lt "$sudo_line" ] || \
  fail 'font destination permissions are checked before requesting sudo'
[ "$duplicate_font_line" -lt "$sudo_line" ] || \
  fail 'font archive filename conflicts are checked before requesting sudo'

printf 'ok - official WezTerm and Nerd Font installer contract\n'
