#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
. "$script_dir/test_helper.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

test_repo="$tmp_dir/repository"
fake_bin="$tmp_dir/fake-bin"
fake_home="$tmp_dir/home"
npm_cache="$tmp_dir/npm-cache"
mkdir -p "$test_repo" "$fake_bin" "$fake_home" "$npm_cache"
cp -R "$repo_dir"/. "$test_repo"/
printf 'home sentinel\n' >"$fake_home/sentinel"
printf 'cache sentinel\n' >"$npm_cache/sentinel"

cat >"$tmp_dir/os-release" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
VERSION_CODENAME=noble
EOF

cat >"$fake_bin/dpkg-query" <<'EOF'
#!/bin/bash
package=${!#}
if [ "${FAKE_DPKG_FAILURE:-}" = "$package" ]; then
  exit 2
fi
if [ "${FAKE_MISSING_APT:-}" = "$package" ]; then
  exit 1
fi
if [ "$package" = neovim ]; then
  version=${FAKE_NEOVIM_VERSION:-0.9.0}
else
  version=1.0
fi
printf 'ii \t%s\n' "$version"
EOF

cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
case ${1:-} in
  --print-architecture)
    printf 'amd64\n'
    ;;
  --compare-versions)
    installed=$2
    operator=$3
    required=$4
    [ "$operator" = ge ] || exit 2
    [ "$installed" = 0.8.3 ] && [ "$required" = 0.9.0 ] && exit 1
    [ "$installed" = 0.8.4 ] && [ "$required" = 0.9.0 ] && exit 1
    exit 0
    ;;
  *) exit 2 ;;
esac
EOF

cat >"$fake_bin/apt-cache" <<'EOF'
#!/bin/bash
[ "${FAKE_APT_CACHE_FAILURE:-0}" -eq 0 ] || exit 2
package=${!#}
if [ "$package" = neovim ]; then
  candidate=${FAKE_NEOVIM_CANDIDATE:-0.9.0}
else
  candidate=1.0
fi
printf '%s:\n  Candidate: %s\n' "$package" "$candidate"
EOF

chmod +x "$fake_bin/dpkg-query" "$fake_bin/dpkg" "$fake_bin/apt-cache"

checksum_tree() {
  directory=$1
  find "$directory" -type f -exec shasum {} \; | LC_ALL=C sort | shasum | awk '{print $1}'
}

run_audit() {
  set +e
  audit_output=$(cd "$test_repo" && env \
    HOME="$fake_home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    SETUP_OS_RELEASE="$tmp_dir/os-release" \
    SETUP_AUDIT_NPM_CACHE="$npm_cache" \
    FAKE_MISSING_APT="${FAKE_MISSING_APT:-}" \
    FAKE_NEOVIM_VERSION="${FAKE_NEOVIM_VERSION:-}" \
    FAKE_NEOVIM_CANDIDATE="${FAKE_NEOVIM_CANDIDATE:-}" \
    FAKE_DPKG_FAILURE="${FAKE_DPKG_FAILURE:-}" \
    FAKE_APT_CACHE_FAILURE="${FAKE_APT_CACHE_FAILURE:-0}" \
    bash bin/audit work 2>&1)
  audit_status=$?
  set -e
}

assert_sections_in_order() {
  output=$1
  previous=0
  for section in 'Platform' 'Missing' 'Incompatible' 'Substitutions' \
    'External assumptions' 'Manager errors' 'Suggested actions'; do
    line=$(printf '%s\n' "$output" | grep -n -x "$section" | cut -d: -f1)
    [ -n "$line" ] || fail "audit prints the $section section"
    [ "$line" -gt "$previous" ] || fail "audit sections have stable ordering"
    previous=$line
  done
}

repo_before=$(checksum_tree "$test_repo")
home_before=$(checksum_tree "$fake_home")
run_audit
assert_eq 0 "$audit_status" 'exact desired state succeeds'
assert_sections_in_order "$audit_output"
assert_contains "$audit_output" $'Missing\n  (none)' 'exact state has an empty Missing section'
assert_contains "$audit_output" $'Incompatible\n  (none)' 'exact state has an empty Incompatible section'
assert_contains "$audit_output" 'command slack: missing' 'missing Slack is reported as an external assumption'
assert_eq "$repo_before" "$(checksum_tree "$test_repo")" 'audit does not modify the repository'
assert_eq "$home_before" "$(checksum_tree "$fake_home")" 'audit does not write to home or caches'

FAKE_MISSING_APT=tree run_audit
assert_eq 1 "$audit_status" 'a missing owned APT package reports drift'
assert_contains "$audit_output" 'APT tree' 'missing tree is reported'
case $audit_output in
  *unrelated-package*) fail 'audit must not report unrelated installed APT packages' ;;
esac

FAKE_NEOVIM_VERSION=0.8.3 FAKE_NEOVIM_CANDIDATE=0.9.0 run_audit
assert_eq 1 "$audit_status" 'an installed version below its floor reports drift'
assert_contains "$audit_output" 'APT neovim: installed 0.8.3, requires 0.9.0' 'installed and required versions are printed'

FAKE_NEOVIM_VERSION=0.8.3 FAKE_NEOVIM_CANDIDATE=0.8.4 run_audit
assert_eq 1 "$audit_status" 'an insufficient candidate remains owned drift'
assert_contains "$audit_output" 'candidate 0.8.4 is below required 0.9.0; no automatic vendor substitution configured' 'insufficient candidate explains the substitution policy'

printf 'prettier\n' >"$test_repo/manifests/npm.txt"
run_audit
assert_eq 2 "$audit_status" 'a needed unavailable npm manager is a configuration error'
assert_contains "$audit_output" 'npm: unavailable' 'missing needed npm is reported as a manager error'
printf '# Intentionally empty.\n' >"$test_repo/manifests/npm.txt"

cat >"$fake_bin/npm" <<'EOF'
#!/bin/bash
safe=1
[ -d "${npm_config_cache:-}" ] || safe=0
case ${npm_config_cache:-} in "$HOME"|"$HOME"/*) safe=0 ;; esac
[ "${npm_config_logs_max:-}" = 0 ] || safe=0
[ "${npm_config_update_notifier:-}" = false ] || safe=0
[ "${npm_config_audit:-}" = false ] || safe=0
[ "${npm_config_fund:-}" = false ] || safe=0
[ "${npm_config_progress:-}" = false ] || safe=0
if [ "$safe" -ne 1 ]; then
  mkdir -p "$HOME/.npm/_logs"
  printf 'npm debug log\n' >"$HOME/.npm/_logs/audit-debug.log"
fi
printf '/opt/npm/lib/node_modules/prettier\n'
EOF
chmod +x "$fake_bin/npm"
printf 'prettier\n' >"$test_repo/manifests/npm.txt"
repo_before=$(checksum_tree "$test_repo")
home_before=$(checksum_tree "$fake_home")
cache_before=$(checksum_tree "$npm_cache")
run_audit
assert_eq 0 "$audit_status" 'a satisfied nonempty npm manifest succeeds'
assert_eq "$repo_before" "$(checksum_tree "$test_repo")" 'npm inventory does not modify the repository'
assert_eq "$home_before" "$(checksum_tree "$fake_home")" 'npm inventory does not create home cache or logs'
assert_eq "$cache_before" "$(checksum_tree "$npm_cache")" 'npm inventory does not modify its disposable cache'
rm "$fake_bin/npm"
printf '# Intentionally empty.\n' >"$test_repo/manifests/npm.txt"

printf 'ruff\n' >"$test_repo/manifests/uv-tools.txt"
run_audit
assert_eq 2 "$audit_status" 'a needed unavailable uv manager is a configuration error'
assert_contains "$audit_output" 'uv: unavailable' 'missing needed uv is reported as a manager error'
printf '# Intentionally empty.\n' >"$test_repo/manifests/uv-tools.txt"

FAKE_DPKG_FAILURE=bat run_audit
assert_eq 2 "$audit_status" 'an APT inventory failure exits with status 2'
assert_contains "$audit_output" 'APT inventory failed for bat' 'APT inventory failure is reported'

mv "$test_repo/manifests/apt-common.txt" "$test_repo/manifests/apt-common.txt.saved"
run_audit
assert_eq 2 "$audit_status" 'a missing manifest exits with status 2'
assert_contains "$audit_output" 'cannot read APT manifest' 'missing manifest failure propagates'
mv "$test_repo/manifests/apt-common.txt.saved" "$test_repo/manifests/apt-common.txt"

chmod 000 "$test_repo/manifests/apt-common.txt"
if [ ! -r "$test_repo/manifests/apt-common.txt" ]; then
  run_audit
  assert_eq 2 "$audit_status" 'an unreadable manifest exits with status 2'
  assert_contains "$audit_output" 'cannot read APT manifest' 'unreadable manifest failure propagates'
fi
chmod 644 "$test_repo/manifests/apt-common.txt"

mv "$test_repo/profiles/work.external.txt" "$test_repo/profiles/work.external.txt.saved"
run_audit
assert_eq 2 "$audit_status" 'a missing external manifest exits with status 2'
mv "$test_repo/profiles/work.external.txt.saved" "$test_repo/profiles/work.external.txt"

chmod 000 "$test_repo/profiles/work.external.txt"
if [ ! -r "$test_repo/profiles/work.external.txt" ]; then
  run_audit
  assert_eq 2 "$audit_status" 'an unreadable external manifest exits with status 2'
  assert_contains "$audit_output" 'cannot read manifest' 'unreadable external manifest failure propagates'
fi
chmod 644 "$test_repo/profiles/work.external.txt"

printf 'ok - audit is stable, scoped, read-only, and status-aware\n'
