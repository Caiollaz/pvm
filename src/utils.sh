#!/usr/bin/env bash
# shellcheck shell=bash
#
# utils.sh — colored logging and small helpers.

[ -n "${_PVM_UTILS_LOADED:-}" ] && return 0
_PVM_UTILS_LOADED=1

if [ -t 2 ]; then
  PVM_C_RED=$'\033[31m'; PVM_C_GRN=$'\033[32m'; PVM_C_YEL=$'\033[33m'
  PVM_C_BLU=$'\033[34m'; PVM_C_DIM=$'\033[2m';  PVM_C_OFF=$'\033[0m'
else
  PVM_C_RED=""; PVM_C_GRN=""; PVM_C_YEL=""; PVM_C_BLU=""; PVM_C_DIM=""; PVM_C_OFF=""
fi

pvm_log()  { printf '%s\n' "$*" >&2; }
pvm_info() { printf '%spvm:%s %s\n' "$PVM_C_BLU" "$PVM_C_OFF" "$*" >&2; }
pvm_ok()   { printf '%spvm:%s %s\n' "$PVM_C_GRN" "$PVM_C_OFF" "$*" >&2; }
pvm_warn() { printf '%spvm:%s %s\n' "$PVM_C_YEL" "$PVM_C_OFF" "$*" >&2; }
pvm_err()  { printf '%spvm:%s %s\n' "$PVM_C_RED" "$PVM_C_OFF" "$*" >&2; }
pvm_die()  { pvm_err "$*"; exit 1; }

# Strip whitespace and a leading "php-"/"php" prefix from a version string.
pvm_normalize_version() {
  local v="$1"
  v="${v#php-}"
  v="${v#php}"
  printf '%s' "$v" | tr -d '[:space:]'
}

# True when stdin and stdout are both TTYs (controls docker -t).
pvm_has_tty() { [ -t 0 ] && [ -t 1 ]; }
