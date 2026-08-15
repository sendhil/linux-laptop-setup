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
  'brightness/backlight' \
  'Slack' \
  'Zoom' \
  'screen sharing' \
  'SSH' \
  'GNOME'; do
  assert_contains "$checklist" "$required_text" "first-login checklist covers $required_text"
done

[ -z "$(git ls-files -- ubuntu)" ] || fail 'tracked legacy ubuntu directory is retired'

supported_docs=$(printf '%s\n%s\n' "$readme" "$checklist")
if printf '%s\n' "$supported_docs" | grep -Eiq \
  'curl[^[:cntrl:]]*\|[^[:cntrl:]]*(ba)?sh|i3-gaps|apt-key|minikube|dropbox'; then
  fail 'supported documentation contains a retired installation instruction'
fi

assert_contains "$readme" 'Fedora' 'README identifies Fedora material'
assert_contains "$readme" 'Lima' 'README identifies Lima material'
assert_contains "$readme" 'historical and unsupported' 'README labels historical platform material unsupported'

[ -x tests/container-smoke.sh ] || fail 'container smoke test is executable'

smoke_tmp=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$smoke_tmp"' EXIT
fake_bin="$smoke_tmp/fake-bin"
safe_bin="$smoke_tmp/safe-bin"
docker_log="$smoke_tmp/docker.log"
mkdir -p "$smoke_tmp/repository with spaces/tests" "$fake_bin" "$safe_bin"
ln -s "$(command -v dirname)" "$safe_bin/dirname"
cp tests/container-smoke.sh "$smoke_tmp/repository with spaces/tests/container-smoke.sh"

cat >"$fake_bin/docker" <<'EOF'
#!/bin/bash
if [ "${1:-}" = info ]; then
  [ "${DOCKER_MODE:-available}" != daemon-unavailable ]
  exit $?
fi
printf '<%s>\n' "$@" >"$DOCKER_LOG"
EOF
chmod +x "$fake_bin/docker"

set +e
smoke_invalid_output=$(DOCKER_LOG="$docker_log" PATH="$fake_bin:$safe_bin" \
  /bin/bash tests/container-smoke.sh --privileged 2>&1)
smoke_invalid_status=$?
set -e
assert_eq 2 "$smoke_invalid_status" 'container smoke rejects an option-like image'
assert_contains "$smoke_invalid_output" 'usage:' 'invalid image prints container smoke usage'

set +e
smoke_invalid_output=$(DOCKER_LOG="$docker_log" PATH="$fake_bin:$safe_bin" \
  /bin/bash tests/container-smoke.sh ubuntu:24.04 extra 2>&1)
smoke_invalid_status=$?
set -e
assert_eq 2 "$smoke_invalid_status" 'container smoke accepts at most one image argument'
assert_contains "$smoke_invalid_output" 'usage:' 'extra arguments print container smoke usage'

DOCKER_LOG="$docker_log" PATH="$fake_bin:$safe_bin" \
  /bin/bash tests/container-smoke.sh example.invalid/ubuntu:test
smoke_call=$(cat "$docker_log")
assert_contains "$smoke_call" '<run>' 'container smoke invokes docker run'
assert_contains "$smoke_call" '<--rm>' 'container smoke removes its disposable container'
assert_contains "$smoke_call" "<$repo_dir:/repo:ro>" 'container smoke mounts the repository read-only'
assert_contains "$smoke_call" '<-w>' 'container smoke selects a container working directory'
assert_contains "$smoke_call" '</repo>' 'container smoke works from the mounted repository'
assert_contains "$smoke_call" '<example.invalid/ubuntu:test>' 'container smoke accepts an optional image'
assert_contains "$smoke_call" 'bash tests/run' 'container smoke runs the repository test suite'
assert_contains "$smoke_call" \
  'apt-get install -y bash coreutils desktop-file-utils findutils git grep libdigest-sha-perl python3 sed' \
  'container smoke installs the complete test-suite prerequisites'
assert_contains "$smoke_call" 'GIT_CONFIG_COUNT=1' \
  'container smoke scopes a Git configuration entry to the container process'
assert_contains "$smoke_call" 'GIT_CONFIG_KEY_0=safe.directory' \
  'container smoke declares the Git safe-directory key without writing config'
assert_contains "$smoke_call" 'GIT_CONFIG_VALUE_0=/repo' \
  'container smoke marks only the mounted repository safe'
assert_contains "$smoke_call" 'bash -n bin/bootstrap bin/audit bin/apply bin/doctor bin/audit-wine bin/install-sway-nvidia-session' \
  'container smoke checks supported command syntax'
case $smoke_call in
  *'bin/apply work'*) fail 'container smoke applies laptop state' ;;
  *'git config --global'*) fail 'container smoke writes global Git configuration' ;;
  *'install docker'*|*'docker install'*|*systemctl*|*service*)
    fail 'container smoke installs or starts Docker'
    ;;
esac

: >"$docker_log"
DOCKER_LOG="$docker_log" PATH="$fake_bin:$safe_bin" \
  /bin/bash tests/container-smoke.sh
assert_contains "$(cat "$docker_log")" '<ubuntu:24.04>' \
  'container smoke defaults to the supported Ubuntu image'

: >"$docker_log"
DOCKER_LOG="$docker_log" PATH="$fake_bin:$safe_bin" \
  /bin/bash "$smoke_tmp/repository with spaces/tests/container-smoke.sh"
assert_contains "$(cat "$docker_log")" "<$smoke_tmp/repository with spaces:/repo:ro>" \
  'container smoke preserves repository paths containing spaces'

set +e
smoke_skip_output=$(PATH="$safe_bin" /bin/bash tests/container-smoke.sh 2>&1)
smoke_skip_status=$?
set -e
assert_eq 0 "$smoke_skip_status" 'container smoke skips cleanly without Docker'
assert_contains "$smoke_skip_output" 'SKIP' 'container smoke reports an unavailable Docker skip'

set +e
smoke_skip_output=$(DOCKER_MODE=daemon-unavailable DOCKER_LOG="$docker_log" \
  PATH="$fake_bin:$safe_bin" /bin/bash tests/container-smoke.sh 2>&1)
smoke_skip_status=$?
set -e
assert_eq 0 "$smoke_skip_status" 'container smoke skips cleanly without a Docker daemon'
assert_contains "$smoke_skip_output" 'SKIP' 'container smoke reports an unavailable Docker daemon skip'

assert_contains "$readme" 'optional local test harness' 'README scopes Docker to local testing'
assert_contains "$readme" 'does not install or start Docker' 'README forbids Docker lifecycle changes'
assert_contains "$readme" 'skip' 'README documents unavailable Docker behavior'

printf 'ok - supported workflow documentation\n'
