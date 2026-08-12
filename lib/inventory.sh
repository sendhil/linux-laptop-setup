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
  if [ "${UV_TOOL_DIR+x}" = x ]; then
    case $UV_TOOL_DIR in
      /*) tool_dir=$UV_TOOL_DIR ;;
      *)
        printf 'error: UV_TOOL_DIR must be absolute\n' >&2
        return 2
        ;;
    esac
  else
    case ${XDG_DATA_HOME:-} in
      /*) tool_dir=$XDG_DATA_HOME/uv/tools ;;
      *)
        case ${HOME:-} in
          /*) tool_dir=$HOME/.local/share/uv/tools ;;
          *)
            printf 'error: HOME must be absolute when resolving the uv tools directory\n' >&2
            return 2
            ;;
        esac
        ;;
    esac
  fi
  while [ "$tool_dir" != / ] && [ "${tool_dir%/}" != "$tool_dir" ]; do
    tool_dir=${tool_dir%/}
  done
  if [ -L "$tool_dir" ]; then
    printf 'error: uv tools directory must not be a symbolic link: %s\n' "$tool_dir" >&2
    return 2
  fi
  if [ ! -e "$tool_dir" ]; then
    return 0
  fi
  if [ ! -d "$tool_dir" ] || [ ! -r "$tool_dir" ] || [ ! -x "$tool_dir" ]; then
    printf 'error: uv tools path is not a readable directory: %s\n' "$tool_dir" >&2
    return 2
  fi

  names=()
  for entry in "$tool_dir"/*; do
    if [ ! -e "$entry" ] && [ ! -L "$entry" ]; then
      continue
    fi
    [ -d "$entry" ] && [ ! -L "$entry" ] || continue
    name=${entry##*/}
    [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || continue
    names+=("$name")
  done
  [ "${#names[@]}" -eq 0 ] || printf '%s\n' "${names[@]}" | LC_ALL=C sort -u
}

external_command_state() {
  command -v "$1" >/dev/null 2>&1
}
