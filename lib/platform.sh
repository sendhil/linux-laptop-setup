#!/bin/bash

load_ubuntu_info() {
  os_release=$1
  if [ ! -r "$os_release" ]; then
    printf 'error: cannot read platform information: %s\n' "$os_release" >&2
    return 2
  fi

  os_id=$(sed -n 's/^ID=//p' "$os_release" | sed -n '1p' | sed 's/^"//; s/"$//')
  os_version_id=$(sed -n 's/^VERSION_ID=//p' "$os_release" | sed -n '1p' | sed 's/^"//; s/"$//')
  os_version_codename=$(sed -n 's/^VERSION_CODENAME=//p' "$os_release" | sed -n '1p' | sed 's/^"//; s/"$//')

  if [ "$os_id" != ubuntu ]; then
    printf 'error: unsupported platform: %s\n' "${os_id:-unknown}" >&2
    return 2
  fi
  if [ -z "$os_version_id" ] || [ -z "$os_version_codename" ]; then
    printf 'error: incomplete Ubuntu platform information\n' >&2
    return 2
  fi

  UBUNTU_ID=$os_id
  UBUNTU_VERSION_ID=$os_version_id
  UBUNTU_VERSION_CODENAME=$os_version_codename
  export UBUNTU_ID UBUNTU_VERSION_ID UBUNTU_VERSION_CODENAME
}

detect_arch() {
  if ! command -v dpkg >/dev/null 2>&1; then
    printf 'error: dpkg is unavailable\n' >&2
    return 2
  fi
  dpkg --print-architecture
}

graphics_summary() {
  if command -v lspci >/dev/null 2>&1; then
    lspci -nnk | sed -n -e '/VGA compatible controller/p' -e '/3D controller/p' -e '/Display controller/p'
  else
    printf 'unavailable (lspci is not installed)\n'
  fi
}

has_sudo() {
  command -v sudo >/dev/null 2>&1
}
