#!/usr/bin/env bash
# shellcheck shell=bash
#
# doctor.sh — environment diagnostics.

[ -n "${_PVM_DOCTOR_LOADED:-}" ] && return 0
_PVM_DOCTOR_LOADED=1

_pvm_check_pass() { printf '  %s✔%s %s\n' "$PVM_C_GRN" "$PVM_C_OFF" "$*"; }
_pvm_check_fail() { printf '  %s✗%s %s\n' "$PVM_C_RED" "$PVM_C_OFF" "$*"; }
_pvm_check_warn() { printf '  %s!%s %s\n'  "$PVM_C_YEL" "$PVM_C_OFF" "$*"; }

pvm_cmd_doctor() {
  local problems=0

  printf '%spvm doctor%s\n\n' "$PVM_C_BLU" "$PVM_C_OFF"

  # Docker installed
  if pvm_docker_installed; then
    _pvm_check_pass "Docker installed ($(docker --version 2>/dev/null))"
  else
    _pvm_check_fail "Docker not found — install: https://docs.docker.com/get-docker/"
    problems=$((problems+1))
  fi

  # Docker daemon
  if pvm_docker_installed && pvm_docker_running; then
    _pvm_check_pass "Docker daemon running"
  else
    _pvm_check_fail "Docker daemon not running or not accessible by this user"
    problems=$((problems+1))
  fi

  # PATH
  case ":$PATH:" in
    *":$PVM_BIN_DIR:"*) _pvm_check_pass "$PVM_BIN_DIR is on PATH" ;;
    *) _pvm_check_warn "$PVM_BIN_DIR not on PATH — add it in your shell rc"; problems=$((problems+1)) ;;
  esac

  # Config dir / global version
  if [ -d "$PVM_CONFIG_DIR" ]; then
    _pvm_check_pass "Config directory present ($PVM_CONFIG_DIR)"
  else
    _pvm_check_warn "Config directory missing ($PVM_CONFIG_DIR)"
  fi

  # Active version
  local v
  if v="$(pvm_resolve_version 2>/dev/null)"; then
    if pvm_image_present "$v"; then
      _pvm_check_pass "Active version: PHP $v (image present)"
    else
      _pvm_check_warn "Active version PHP $v selected but image not installed — run: pvm install $v"
      problems=$((problems+1))
    fi
  else
    _pvm_check_warn "No active version selected — run: pvm use <version>"
  fi

  # Composer phar
  if [ -f "$PVM_COMPOSER_PHAR" ]; then
    _pvm_check_pass "Composer cached ($PVM_COMPOSER_PHAR)"
  else
    _pvm_check_warn "Composer not fetched yet (downloads on first 'composer' call)"
  fi

  echo
  if [ "$problems" -eq 0 ]; then
    pvm_ok "Everything looks good."
  else
    pvm_warn "$problems issue(s) found. See above."
    return 1
  fi
}
