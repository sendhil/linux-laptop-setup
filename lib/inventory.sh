#!/bin/bash

apt_installed_version() {
  package=$1
  output=$(dpkg-query -W -f='${db:Status-Abbrev}\t${Version}\n' "$package" 2>/dev/null)
  status=$?
  case $status in
    0)
      record_status=${output%%$'\t'*}
      version=${output#*$'\t'}
      case $record_status in
        ii*|hi*) printf '%s\n' "$version" ;;
      esac
      ;;
    1) return 0 ;;
    *) return 2 ;;
  esac
}

apt_candidate_version() {
  package=$1
  output=$(apt-cache policy "$package" 2>/dev/null)
  status=$?
  [ "$status" -eq 0 ] || return 2
  candidate=$(printf '%s\n' "$output" | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p' | sed -n '1p')
  [ "$candidate" = '(none)' ] || printf '%s\n' "$candidate"
}

npm_inventory() {
  npm_cache=${SETUP_AUDIT_NPM_CACHE:-${TMPDIR:-/tmp}}
  [ -d "$npm_cache" ] || return 2
  output=$(NODE_DISABLE_COMPILE_CACHE=1 \
    npm_config_cache="$npm_cache" \
    npm_config_logs_max=0 \
    npm_config_update_notifier=false \
    npm_config_audit=false \
    npm_config_fund=false \
    npm_config_progress=false \
    npm list --global --depth=0 --parseable 2>/dev/null)
  status=$?
  [ "$status" -eq 0 ] || return 2
  printf '%s\n' "$output" | sed -n 's|^.*node_modules/||p'
}

uv_inventory() {
  tool_dir=${UV_TOOL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/uv/tools}
  if [ ! -e "$tool_dir" ] && [ ! -L "$tool_dir" ]; then
    return 0
  fi
  [ -d "$tool_dir" ] && [ -r "$tool_dir" ] || return 2
  entries=$(find "$tool_dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -exec basename {} \; 2>/dev/null) || return 2
  [ -z "$entries" ] || printf '%s\n' "$entries" | \
    sed -n '/^[a-z0-9][a-z0-9-]*$/ { /--/d; /-$/d; p; }' | LC_ALL=C sort -u
}

external_command_state() {
  command -v "$1" >/dev/null 2>&1
}
