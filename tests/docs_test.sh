#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

cd "$repo_dir"

readme=$(cat README.md)
for required_text in \
  'bin/bootstrap' \
  'bin/audit work' \
  'bin/apply work' \
  'bin/doctor work' \
  'GNOME fallback' \
  'externally managed' \
  'pre-modernization-2026-08-11'; do
  assert_contains "$readme" "$required_text" "README documents $required_text"
done

[ -f docs/first-sway-login.md ] || fail 'first Sway login checklist exists'
checklist=$(cat docs/first-sway-login.md)
for required_text in \
  'proprietary NVIDIA' \
  'Slack' \
  'Zoom' \
  'screen sharing' \
  'SSH' \
  'GNOME'; do
  assert_contains "$checklist" "$required_text" "first-login checklist covers $required_text"
done

[ ! -e ubuntu ] || fail 'tracked legacy ubuntu directory is retired'

supported_docs=$(printf '%s\n%s\n' "$readme" "$checklist")
if printf '%s\n' "$supported_docs" | grep -Eiq \
  'curl[^[:cntrl:]]*\|[^[:cntrl:]]*(ba)?sh|i3-gaps|apt-key|minikube|dropbox'; then
  fail 'supported documentation contains a retired installation instruction'
fi

assert_contains "$readme" 'Fedora' 'README identifies Fedora material'
assert_contains "$readme" 'Lima' 'README identifies Lima material'
assert_contains "$readme" 'historical and unsupported' 'README labels historical platform material unsupported'

printf 'ok - supported workflow documentation\n'
