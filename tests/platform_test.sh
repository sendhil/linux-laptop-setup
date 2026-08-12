#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname "$script_dir")
. "$script_dir/test_helper.sh"
. "$repo_root/lib/platform.sh"

load_ubuntu_info_quiet() { load_ubuntu_info "$@" 2>/dev/null; }

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

ubuntu_fixture="$test_root/ubuntu-os-release"
cat >"$ubuntu_fixture" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
EOF

load_ubuntu_info "$ubuntu_fixture"
assert_eq ubuntu "$UBUNTU_ID" "Ubuntu ID is exported"
assert_eq 24.04 "$UBUNTU_VERSION_ID" "Ubuntu version is exported"
assert_eq noble "$UBUNTU_VERSION_CODENAME" "Ubuntu codename is exported"

debian_fixture="$test_root/debian-os-release"
cat >"$debian_fixture" <<'EOF'
ID=debian
VERSION_ID="12"
VERSION_CODENAME=bookworm
EOF
assert_status 2 load_ubuntu_info_quiet "$debian_fixture"

fake_bin="$test_root/fake-bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
[ "${1:-}" = --print-architecture ] && printf 'amd64\n'
EOF
cat >"$fake_bin/lspci" <<'EOF'
#!/bin/bash
printf '00:02.0 VGA compatible controller: Example Graphics\n'
EOF
cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$fake_bin/dpkg" "$fake_bin/lspci" "$fake_bin/sudo"

assert_eq amd64 "$(PATH="$fake_bin:$PATH" detect_arch)" "detect_arch uses dpkg architecture"
assert_contains "$(PATH="$fake_bin:$PATH" graphics_summary)" 'Example Graphics' "graphics_summary reports lspci output"
assert_status 0 env PATH="$fake_bin" /bin/bash -c ". '$repo_root/lib/platform.sh'; has_sudo"
assert_status 1 env PATH=/nonexistent /bin/bash -c ". '$repo_root/lib/platform.sh'; has_sudo"

printf 'ok - platform contracts\n'
