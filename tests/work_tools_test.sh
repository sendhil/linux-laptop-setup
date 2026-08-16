#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

cd "$repo_dir"
[ -x bin/install-work-tools ] || fail 'work-tools installer is executable'

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

cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo %s\n' "$*" >>"$SETUP_TEST_LOG"
if [ "${1:-}" = -v ]; then
  exit 0
fi
exec "$@"
EOF

cat >"$fake_bin/snap" <<'EOF'
#!/bin/bash
printf 'snap %s\n' "$*" >>"$SETUP_TEST_LOG"
case ${1:-} in
  list) command -v "${2:-}" >/dev/null 2>&1 ;;
  install)
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/$2"
    chmod +x "$HOME/.local/bin/$2"
    ;;
  *) exit 2 ;;
esac
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/bin/bash
output=
url=
while [ "$#" -gt 0 ]; do
  case $1 in
    -o|--output) output=$2; shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
[ -n "$output" ] || exit 2
printf 'curl %s\n' "$url" >>"$SETUP_TEST_LOG"
case $url in
  https://herdr.dev/install.sh)
    body='mkdir -p "$HERDR_INSTALL_DIR"; printf "#!/bin/sh\\nexit 0\\n" >"$HERDR_INSTALL_DIR/herdr"; chmod +x "$HERDR_INSTALL_DIR/herdr"'
    ;;
  https://astral.sh/uv/install.sh)
    body='mkdir -p "$XDG_BIN_HOME"; for c in uv uvx; do printf "#!/bin/sh\\nexit 0\\n" >"$XDG_BIN_HOME/$c"; chmod +x "$XDG_BIN_HOME/$c"; done'
    ;;
  https://bun.sh/install)
    body='mkdir -p "$BUN_INSTALL/bin"; for c in bun bunx; do printf "#!/bin/sh\\nexit 0\\n" >"$BUN_INSTALL/bin/$c"; chmod +x "$BUN_INSTALL/bin/$c"; done'
    ;;
  https://get.pnpm.io/install.sh)
    body='[ "${SHELL:-}" = /bin/sh ] || exit 41; [ "${ENV:-}" = "$HOME/.shrc" ] || exit 42; [ -f "$ENV" ] || exit 43; printf "export PNPM_HOME=%s\\n" "$PNPM_HOME" >>"$ENV"; mkdir -p "$PNPM_HOME/bin"; printf "#!/bin/sh\\nexit 0\\n" >"$PNPM_HOME/bin/pnpm"; chmod +x "$PNPM_HOME/bin/pnpm"'
    ;;
  https://opencode.ai/install)
    body='mkdir -p "$HOME/.opencode/bin"; printf "#!/bin/sh\\nexit 0\\n" >"$HOME/.opencode/bin/opencode"; chmod +x "$HOME/.opencode/bin/opencode"'
    ;;
  https://pi.dev/install.sh)
    body='[ "${HOME##*/}" = pi-home ] || exit 51; [ "$ZDOTDIR" = "$HOME" ] || exit 52; mkdir -p "$HOME/.local/share/pi-node/current/bin"; printf "#!/bin/sh\\nexit 0\\n" >"$HOME/.local/share/pi-node/current/bin/pi"; chmod +x "$HOME/.local/share/pi-node/current/bin/pi"; printf "export PATH=changed\\n" >"$HOME/.zshrc"'
    ;;
  *) exit 3 ;;
esac
printf '#!/bin/sh\nset -eu\n%s\n' "$body" >"$output"
EOF

for command_name in difft eza yazi ya dust; do
  printf '#!/bin/sh\nexit 0\n' >"$fake_bin/$command_name"
done
chmod +x "$fake_bin"/*

run_installer() {
  env HOME="$fake_home" \
    PATH="$fake_home/.local/bin:$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="$os_release" \
    SETUP_TEST_LOG="$log" \
    "$repo_dir/bin/install-work-tools" "$@"
}

set +e
invalid_output=$(run_installer unexpected 2>&1)
invalid_status=$?
set -e
assert_eq 2 "$invalid_status" 'work-tools installer rejects arguments'
assert_contains "$invalid_output" 'usage:' 'invalid work-tools input prints usage'
[ ! -s "$log" ] || fail 'invalid work-tools input caused a mutation'

run_installer >/dev/null
[ ! -e "$fake_home/.shrc" ] || fail 'pnpm installer modified the real shell configuration'
[ ! -e "$fake_home/.zshrc" ] || fail 'Pi installer modified the real shell configuration'
for command_name in herdr uv uvx bun bunx pnpm opencode pi; do
  [ -x "$fake_home/.local/bin/$command_name" ] || fail "$command_name was not installed into the user command directory"
done
assert_eq "$fake_home/.local/share/pnpm/bin/pnpm" "$(readlink "$fake_home/.local/bin/pnpm")" 'pnpm links the standalone binary from its current install layout'
assert_eq "$fake_home/.local/share/pi-node/current/bin/pi" "$(readlink "$fake_home/.local/bin/pi")" 'Pi links the official private runtime command into the user command directory'
actions=$(cat "$log")
assert_contains "$actions" 'sudo -v' 'desktop installs preflight sudo'
assert_contains "$actions" 'sudo snap install code --classic' 'VS Code uses the official snap'
assert_contains "$actions" 'sudo snap install obsidian --classic' 'Obsidian uses the official snap'
for url in \
  https://herdr.dev/install.sh \
  https://astral.sh/uv/install.sh \
  https://bun.sh/install \
  https://get.pnpm.io/install.sh \
  https://opencode.ai/install \
  https://pi.dev/install.sh; do
  assert_contains "$actions" "curl $url" "installer does not use the official source $url"
done
case $actions in
  *chatgpt.com/codex/install.sh*) fail 'work-tools installer still downloads Codex' ;;
  *claude.ai/install.sh*) fail 'work-tools installer still downloads Claude Code' ;;
esac
case $actions in
  *' npm '*|*' node '*) fail 'work-tools installer directly manages Node or npm' ;;
esac

before=$(wc -l <"$log")
run_installer >/dev/null
after=$(wc -l <"$log")
assert_eq "$before" "$after" 'converged work-tools rerun performs no installation work'

partial_home="$tmp_dir/partial-home"
mkdir -p "$partial_home/.local/share/pnpm/bin"
printf '#!/bin/sh\nexit 0\n' >"$partial_home/.local/share/pnpm/bin/pnpm"
chmod +x "$partial_home/.local/share/pnpm/bin/pnpm"
: >"$log"
env HOME="$partial_home" \
  PATH="$fake_bin:/usr/bin:/bin" \
  SETUP_OS_RELEASE="$os_release" \
  SETUP_TEST_LOG="$log" \
  "$repo_dir/bin/install-work-tools" >/dev/null
[ -x "$partial_home/.local/bin/pnpm" ] || fail 'partial pnpm installation was not recovered'
assert_eq "$partial_home/.local/share/pnpm/bin/pnpm" "$(readlink "$partial_home/.local/bin/pnpm")" 'partial pnpm recovery links the existing standalone binary'
partial_actions=$(cat "$log")
case $partial_actions in
  *'curl https://get.pnpm.io/install.sh'*) fail 'partial pnpm recovery downloaded the installer again' ;;
esac

partial_pi_home="$tmp_dir/pi-partial-home"
mkdir -p "$partial_pi_home/.local/share/pi-node/current/bin"
printf '#!/bin/sh\nexit 0\n' >"$partial_pi_home/.local/share/pi-node/current/bin/pi"
chmod +x "$partial_pi_home/.local/share/pi-node/current/bin/pi"
: >"$log"
env HOME="$partial_pi_home" \
  PATH="$fake_bin:/usr/bin:/bin" \
  SETUP_OS_RELEASE="$os_release" \
  SETUP_TEST_LOG="$log" \
  "$repo_dir/bin/install-work-tools" >/dev/null
[ -x "$partial_pi_home/.local/bin/pi" ] || fail 'partial Pi installation was not recovered'
assert_eq "$partial_pi_home/.local/share/pi-node/current/bin/pi" "$(readlink "$partial_pi_home/.local/bin/pi")" 'partial Pi recovery links the existing official private-runtime command'
partial_pi_actions=$(cat "$log")
case $partial_pi_actions in
  *'curl https://pi.dev/install.sh'*) fail 'partial Pi recovery downloaded the installer again' ;;
esac

conflict_home="$tmp_dir/conflict-home"
mkdir -p "$conflict_home/.local/bin"
printf 'not executable\n' >"$conflict_home/.local/bin/herdr"
: >"$log"
set +e
conflict_output=$(env HOME="$conflict_home" \
  PATH="$fake_bin:/usr/bin:/bin" \
  SETUP_OS_RELEASE="$os_release" \
  SETUP_TEST_LOG="$log" \
  "$repo_dir/bin/install-work-tools" 2>&1)
conflict_status=$?
set -e
assert_eq 2 "$conflict_status" 'conflicting user command is rejected before mutation'
assert_contains "$conflict_output" 'refusing to overwrite' 'conflict rejection is actionable'
[ ! -s "$log" ] || fail 'conflicting user command was detected after mutation began'

printf 'ok - official work-tool installer\n'
