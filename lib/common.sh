#!/bin/bash

sorted_unique() {
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' -e '/^#/d' | LC_ALL=C sort -u
}

read_lines() {
  if [ ! -f "$1" ] || [ ! -r "$1" ]; then
    printf 'error: cannot read manifest: %s\n' "$1" >&2
    return 2
  fi
  sorted_unique <"$1"
}

validate_profile() {
  profile=$1
  case $profile in
    ''|*[!A-Za-z0-9._-]*)
      printf 'error: unknown profile: %s\n' "$profile" >&2
      return 2
      ;;
  esac
  if [ -f "profiles/$profile.apt.txt" ] && [ -f "profiles/$profile.external.txt" ]; then
    return 0
  fi
  printf 'error: unknown profile: %s\n' "$profile" >&2
  return 2
}

validate_apt_entry() {
  line=$1
  set -f
  set -- $line
  set +f
  [ "$#" -ge 1 ] && [ "$#" -le 2 ] || return 2
  [[ $1 =~ ^[a-z0-9][a-z0-9+.-]+(:[a-z0-9][a-z0-9-]*)?$ ]] || return 2
  if [ "$#" -eq 2 ]; then
    case $2 in
      ''|*[!A-Za-z0-9.+:~_-]*) return 2 ;;
    esac
  fi
  printf '%s\t%s\n' "$1" "${2:-}"
}

read_apt_file() {
  if [ ! -f "$1" ] || [ ! -r "$1" ]; then
    printf 'error: cannot read APT manifest: %s\n' "$1" >&2
    return 2
  fi
  records=$(
    while IFS= read -r line; do
      validate_apt_entry "$line" || exit 2
    done < <(read_lines "$1")
  ) || return 2
  [ -z "$records" ] || printf '%s\n' "$records" | LC_ALL=C sort -u
}

load_apt_requirements() {
  profile=$1
  validate_profile "$profile" || return 2
  requirements=$(
    read_apt_file manifests/apt-common.txt || exit 2
    read_apt_file manifests/apt-sway.txt || exit 2
    read_apt_file "profiles/$profile.apt.txt" || exit 2
  ) || return 2
  [ -z "$requirements" ] || printf '%s\n' "$requirements" | LC_ALL=C sort -u
}

validate_tool_id() {
  type=$1
  id=$2
  case $type in
    npm)
      case $id in
        ''|-*|/*|@|@/*|*@*@*|*[!A-Za-z0-9@/._+-]*) return 2 ;;
      esac
      ;;
    uv|command)
      case $id in
        ''|-*|*[!A-Za-z0-9._+-]*) return 2 ;;
      esac
      ;;
    *) return 2 ;;
  esac
}

read_tool_file() {
  type=$1
  file=$2
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    printf 'error: cannot read %s manifest: %s\n' "$type" "$file" >&2
    return 2
  fi
  records=$(
    while IFS= read -r id; do
      validate_tool_id "$type" "$id" || exit 2
      printf '%s\n' "$id"
    done < <(read_lines "$file")
  ) || return 2
  [ -z "$records" ] || printf '%s\n' "$records" | LC_ALL=C sort -u
}

load_external_assumptions() {
  profile=$1
  validate_profile "$profile" || return 2
  read_lines_command=${SETUP_READ_LINES_COMMAND:-read_lines}
  if ! validate_tool_id command "$read_lines_command" || \
    ! command -v "$read_lines_command" >/dev/null 2>&1; then
    printf 'error: invalid manifest reader: %s\n' "$read_lines_command" >&2
    return 2
  fi
  lines=$("$read_lines_command" "profiles/$profile.external.txt") || return 2
  [ -n "$lines" ] || return 0
  records=$(
    while IFS= read -r line; do
      set -f
      set -- $line
      set +f
      [ "$#" -eq 2 ] && [ "$1" = command ] && validate_tool_id command "$2" || exit 2
      printf 'command\t%s\n' "$2"
    done <<<"$lines"
  ) || return 2
  [ -z "$records" ] || printf '%s\n' "$records" | LC_ALL=C sort -u
}

append_line() {
  values=$1
  value=$2
  if [ -n "$values" ]; then
    printf '%s\n%s\n' "$values" "$value"
  else
    printf '%s\n' "$value"
  fi
}

print_section() {
  title=$1
  values=$2
  printf '%s\n' "$title"
  if [ -n "$values" ]; then
    while IFS= read -r value; do
      printf '  %s\n' "$value"
    done <<<"$values"
  else
    printf '  (none)\n'
  fi
}
