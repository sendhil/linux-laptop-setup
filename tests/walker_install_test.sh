#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

cd "$repo_dir"
[ -x bin/install-walker ] || fail 'Walker installer is executable'

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_home="$tmp_dir/home"
fake_bin="$tmp_dir/bin"
log="$tmp_dir/actions.log"
os_release="$tmp_dir/os-release"
mkdir -p "$fake_home" "$fake_bin"
printf 'ID=ubuntu\nVERSION_ID="22.04"\nVERSION_CODENAME=jammy\n' >"$os_release"
: >"$log"

cat >"$fake_bin/id" <<'EOF'
#!/bin/bash
if [ "${1:-}" = -u ]; then
  printf '1000\n'
else
  /usr/bin/id "$@"
fi
EOF

cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
[ "${1:-}" = --print-architecture ] || exit 2
printf 'amd64\n'
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/bin/bash
output=
url=
while [ "$#" -gt 0 ]; do
  case $1 in
    -o) output=$2; shift 2 ;;
    http://*|https://*) url=$1; shift ;;
    *) shift ;;
  esac
done
[ -n "$output" ] || exit 2
printf '%s\n' "$url" >>"$SETUP_TEST_LOG"
printf 'archive fixture for %s\n' "$url" >"$output"
EOF

cat >"$fake_bin/sha256sum" <<'EOF'
#!/bin/bash
[ "${1:-}" = --check ] || exit 2
[ "${2:-}" = --status ] || exit 2
IFS=' ' read -r expected archive
printf 'checksum %s %s\n' "$expected" "$archive" >>"$SETUP_TEST_LOG"
[ -s "$archive" ] || exit 4
[ "${FAKE_WALKER_CHECKSUM_FAIL:-0}" -eq 0 ] || exit 5
EOF

cat >"$fake_bin/tar" <<'EOF'
#!/bin/bash
printf 'tar %s\n' "$*" >>"$SETUP_TEST_LOG"
archive=${2:-}
case ${1:-} in
  -tzf)
    case $archive in
      *walker*) printf 'walker\n' ;;
      *elephant*) printf 'elephant\n' ;;
      *) provider=${archive##*/}; provider=${provider%%-*}; printf '%s.so\n' "$provider" ;;
    esac
    ;;
  -xzf)
    [ "${3:-}" = -C ] || exit 2
    extract_dir=$4
    mkdir -p "$extract_dir"
    case $archive in
      *walker*) printf '#!/bin/sh\nexit 0\n' >"$extract_dir/walker"; chmod +x "$extract_dir/walker" ;;
      *elephant*) printf '#!/bin/sh\nexit 0\n' >"$extract_dir/elephant"; chmod +x "$extract_dir/elephant" ;;
      *) provider=${archive##*/}; provider=${provider%%-*}; printf 'provider %s\n' "$provider" >"$extract_dir/$provider.so" ;;
    esac
    ;;
  *) exit 2 ;;
esac
EOF

chmod +x "$fake_bin"/*

run_installer() {
  env HOME="$fake_home" \
    XDG_DATA_HOME="$fake_home/.local/share" \
    XDG_CONFIG_HOME="$fake_home/.config" \
    PATH="$fake_home/.local/bin:$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="$os_release" \
    SETUP_TEST_LOG="$log" \
    FAKE_WALKER_CHECKSUM_FAIL="${FAKE_WALKER_CHECKSUM_FAIL:-0}" \
    "$repo_dir/bin/install-walker" "$@"
}

set +e
failure_output=$(FAKE_WALKER_CHECKSUM_FAIL=1 run_installer 2>&1)
failure_status=$?
set -e
assert_eq 1 "$failure_status" 'Walker checksum mismatch is rejected'
assert_contains "$failure_output" 'walker archive checksum' \
  'Walker checksum failure is actionable'
case $(cat "$log") in
  *'tar -xzf'*) fail 'Walker checksum failure extracted an archive' ;;
esac
[ ! -e "$fake_home/.local/bin/walker" ] || fail 'Walker checksum failure activated a command'

: >"$log"
run_installer >/dev/null

for command_name in walker elephant; do
  [ -x "$fake_home/.local/bin/$command_name" ] || fail "$command_name was not installed"
done

providers_root="$fake_home/.local/share/work-laptop-tools/walker/elephant/v2.22.0/providers"
for provider in desktopapplications providerlist bookmarks clipboard snippets menus; do
  [ -f "$providers_root/$provider.so" ] || fail "$provider provider was not installed"
done

assert_eq "$fake_home/.local/share/work-laptop-tools/walker/walker/v2.17.0/walker" \
  "$(readlink "$fake_home/.local/bin/walker")" \
  'Walker links the pinned managed binary'
assert_eq "$fake_home/.local/share/work-laptop-tools/walker/elephant/v2.22.0/elephant" \
  "$(readlink "$fake_home/.local/bin/elephant")" \
  'Elephant links the pinned managed binary'
assert_eq "$providers_root" "$(readlink "$fake_home/.config/elephant/providers")" \
  'Elephant provider configuration points at the XDG data-managed provider directory'

for asset_url in \
  'https://github.com/abenz1267/walker/releases/download/v2.17.0/walker-v2.17.0-x86_64-unknown-linux-gnu.tar.gz' \
  'https://github.com/abenz1267/elephant/releases/download/v2.22.0/elephant-linux-amd64.tar.gz' \
  'https://github.com/abenz1267/elephant/releases/download/v2.22.0/desktopapplications-linux-amd64.tar.gz' \
  'https://github.com/abenz1267/elephant/releases/download/v2.22.0/providerlist-linux-amd64.tar.gz' \
  'https://github.com/abenz1267/elephant/releases/download/v2.22.0/bookmarks-linux-amd64.tar.gz' \
  'https://github.com/abenz1267/elephant/releases/download/v2.22.0/clipboard-linux-amd64.tar.gz' \
  'https://github.com/abenz1267/elephant/releases/download/v2.22.0/snippets-linux-amd64.tar.gz' \
  'https://github.com/abenz1267/elephant/releases/download/v2.22.0/menus-linux-amd64.tar.gz'; do
  assert_contains "$(cat "$log")" "$asset_url" 'installer uses the pinned official Walker asset URL'
done

for checksum in \
  eab433ca0f81b4fd2ab611bb00833c5b33df4c883475c763bb1d7337eb0908fb \
  4370562d65ae23eb3398e0b80ad429e7049197e17647e8c7526c709b89df8340 \
  c5e527d2538b60b51297d9fe3cb0ce0867db89dce264464be278a4896658eb54 \
  82f0de50e4e0e343cee1333e67b1f4ac372f44b94bc24390cd7ace5cce97f500 \
  49041b19175048c97338be68e1560751ea2ead783a949cba3886f651907bc789 \
  9af4030af240339b8027143d50f178350c2734c0167062e1ed8aeaf051f3e722 \
  b506653cc119dd8a6e1be9361bbf249f56827593b5c4b9effe8d4d878eb57c11 \
  b93795af000ca2269b77b43d1035292087b39fe45c12728c4b299efe6140e9a6; do
  assert_contains "$(cat "$log")" "$checksum" 'installer verifies the pinned Walker/Elephant checksum'
done

before=$(wc -l <"$log")
run_installer >/dev/null
after=$(wc -l <"$log")
assert_eq "$before" "$after" 'converged Walker rerun performs no installation work'

printf 'ok - verified Walker runtime installer\n'
