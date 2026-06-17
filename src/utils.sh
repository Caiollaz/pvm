#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
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

pvm_normalize_lang() {
  case "${1:-}" in
    pt|pt_BR|pt-BR|portuguese|Portuguese) printf 'pt' ;;
    en|en_US|en-US|english|English) printf 'en' ;;
    *) return 1 ;;
  esac
}

pvm_lang() {
  local lang
  if [ -n "${PVM_LANG:-}" ] && lang="$(pvm_normalize_lang "$PVM_LANG")"; then
    printf '%s\n' "$lang"; return 0
  fi
  if [ -f "$PVM_LANG_FILE" ] && lang="$(pvm_normalize_lang "$(cat "$PVM_LANG_FILE")")"; then
    printf '%s\n' "$lang"; return 0
  fi
  printf 'pt\n'
}

pvm_lang_is_pt() { [ "$(pvm_lang)" = "pt" ]; }

pvm_set_language() {
  local lang
  lang="$(pvm_normalize_lang "$1")" || return 1
  mkdir -p "$PVM_CONFIG_DIR"
  printf '%s\n' "$lang" > "$PVM_LANG_FILE"
}

pvm_cmd_language() {
  local lang="${1:-}"
  if [ -z "$lang" ]; then
    pvm_lang_is_pt && pvm_info "Idioma atual: portugues (pt). Use: pvm language en" || pvm_info "Current language: English (en). Use: pvm language pt"
    return 0
  fi
  pvm_set_language "$lang" || pvm_die "Invalid language. Use: pvm language pt | en"
  pvm_lang_is_pt && pvm_ok "Idioma salvo: portugues." || pvm_ok "Language saved: English."
}

# Strip whitespace and a leading "php-"/"php" prefix from a version string.
pvm_normalize_version() {
  local v="$1"
  v="${v#php-}"
  v="${v#php}"
  printf '%s' "$v" | tr -d '[:space:]'
}

# True when stdin and stdout are both TTYs (controls docker -t).
pvm_has_tty() { [ -t 0 ] && [ -t 1 ]; }
