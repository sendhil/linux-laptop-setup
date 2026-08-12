#!/bin/bash

fail() { printf 'not ok - %s\n' "$1" >&2; return 1; }

assert_eq() {
  expected=$1 actual=$2 description=$3
  [ "$expected" = "$actual" ] || fail "$description (expected '$expected', got '$actual')"
}

assert_status() {
  expected=$1
  shift
  set +e
  "$@"
  actual=$?
  set -e
  [ "$expected" -eq "$actual" ] || fail "expected status $expected, got $actual: $*"
}

assert_contains() {
  case $1 in
    *"$2"*) : ;;
    *) fail "$3 (missing '$2')" ;;
  esac
}
