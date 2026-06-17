#!/usr/bin/env bash
# shellcheck shell=bash
#
# doctor.sh — environment diagnostics.

[ -n "${_PVM_DOCTOR_LOADED:-}" ] && return 0
_PVM_DOCTOR_LOADED=1

_pvm_check_pass() { printf '  %s✔%s %s\n' "$PVM_C_GRN" "$PVM_C_OFF" "$*"; }
_pvm_check_fail() { printf '  %s✗%s %s\n' "$PVM_C_RED" "$PVM_C_OFF" "$*"; }
_pvm_check_warn() { printf '  %s!%s %s\n'  "$PVM_C_YEL" "$PVM_C_OFF" "$*"; }
_pvm_check_note() {
  local line
  while IFS= read -r line; do
    printf '    %s\n' "$line"
  done
}

pvm_cmd_doctor() {
  local problems=0

  printf '%spvm doctor%s\n\n' "$PVM_C_BLU" "$PVM_C_OFF"

  # Docker installed
  if pvm_docker_installed; then
    pvm_lang_is_pt && _pvm_check_pass "Docker encontrado ($(docker --version 2>/dev/null))" || _pvm_check_pass "Docker installed ($(docker --version 2>/dev/null))"
  else
    pvm_lang_is_pt && _pvm_check_fail "Docker ainda nao foi encontrado" || _pvm_check_fail "Docker not found"
    pvm_docker_install_hint | _pvm_check_note
    problems=$((problems+1))
  fi

  # Docker daemon
  if ! pvm_docker_installed; then
    :
  elif pvm_docker_running; then
    pvm_lang_is_pt && _pvm_check_pass "Docker esta rodando" || _pvm_check_pass "Docker daemon running"
  else
    pvm_lang_is_pt && _pvm_check_fail "Docker nao esta rodando ou este usuario nao consegue acessa-lo" || _pvm_check_fail "Docker daemon not running or not accessible by this user"
    pvm_docker_start_hint | _pvm_check_note
    problems=$((problems+1))
  fi

  # PATH
  case ":$PATH:" in
    *":$PVM_BIN_DIR:"*) pvm_lang_is_pt && _pvm_check_pass "$PVM_BIN_DIR esta no PATH" || _pvm_check_pass "$PVM_BIN_DIR is on PATH" ;;
    *) pvm_lang_is_pt && _pvm_check_warn "$PVM_BIN_DIR nao esta no PATH - adicione no arquivo rc do seu shell" || _pvm_check_warn "$PVM_BIN_DIR not on PATH - add it in your shell rc"; problems=$((problems+1)) ;;
  esac

  # Config dir / global version
  if [ -d "$PVM_CONFIG_DIR" ]; then
    pvm_lang_is_pt && _pvm_check_pass "Diretorio de config encontrado ($PVM_CONFIG_DIR)" || _pvm_check_pass "Config directory present ($PVM_CONFIG_DIR)"
  else
    pvm_lang_is_pt && _pvm_check_warn "Diretorio de config ainda nao existe ($PVM_CONFIG_DIR)" || _pvm_check_warn "Config directory missing ($PVM_CONFIG_DIR)"
  fi

  # Active version
  local v
  if v="$(pvm_resolve_version 2>/dev/null)"; then
    if pvm_image_present "$v"; then
      pvm_lang_is_pt && _pvm_check_pass "Versao ativa: PHP $v (imagem presente)" || _pvm_check_pass "Active version: PHP $v (image present)"
    else
      pvm_lang_is_pt && _pvm_check_warn "PHP $v esta selecionado, mas a imagem ainda nao foi instalada - rode: pvm install $v" || _pvm_check_warn "Active version PHP $v selected but image not installed - run: pvm install $v"
      problems=$((problems+1))
    fi
  else
    pvm_lang_is_pt && _pvm_check_warn "Nenhuma versao ativa selecionada - rode: pvm use <version>" || _pvm_check_warn "No active version selected - run: pvm use <version>"
  fi

  # Composer phar
  if [ -f "$PVM_COMPOSER_PHAR" ]; then
    pvm_lang_is_pt && _pvm_check_pass "Composer em cache ($PVM_COMPOSER_PHAR)" || _pvm_check_pass "Composer cached ($PVM_COMPOSER_PHAR)"
  else
    pvm_lang_is_pt && _pvm_check_warn "Composer ainda nao foi baixado (baixa no primeiro comando 'composer')" || _pvm_check_warn "Composer not fetched yet (downloads on first 'composer' call)"
  fi

  echo
  if [ "$problems" -eq 0 ]; then
    pvm_lang_is_pt && pvm_ok "Tudo certo por aqui." || pvm_ok "Everything looks good."
  else
    pvm_lang_is_pt && pvm_warn "$problems problema(s) encontrado(s). Veja acima." || pvm_warn "$problems issue(s) found. See above."
    return 1
  fi
}
