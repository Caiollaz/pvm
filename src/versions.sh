#!/usr/bin/env bash
# shellcheck shell=bash
#
# versions.sh — install/uninstall/list/available/use/current + resolution.

[ -n "${_PVM_VERSIONS_LOADED:-}" ] && return 0
_PVM_VERSIONS_LOADED=1

# Extract the first major.minor pair from a PHP constraint.
pvm_constraint_to_version() {
  local v
  v="$(printf '%s\n' "$1" | grep -oE '[0-9]+\.[0-9]+' | head -n 1 || true)"
  [ -n "$v" ] || return 1
  printf '%s\n' "$v"
}

# Extract require.php from a composer.json and normalize it to major.minor.
pvm_php_from_composer() {
  local file="$1"
  local in_require=0 line
  [ -f "$file" ] || return 1
  while IFS= read -r line; do
    if [ "$in_require" -eq 0 ]; then
      [[ "$line" =~ \"require\"[[:space:]]*:[[:space:]]*\{ ]] || continue
      in_require=1
    fi
    if [[ "$line" =~ \"php\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      pvm_constraint_to_version "${BASH_REMATCH[1]}"
      return $?
    fi
    [[ "$line" =~ \} ]] && in_require=0
  done < "$file"
  return 1
}

# Search up from CWD for a .pvmrc and echo its version (empty + 1 if none).
pvm_find_rc_version() {
  local dir="$PWD"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/$PVM_RC_FILE" ]; then
      pvm_normalize_version "$(cat "$dir/$PVM_RC_FILE")"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# Search up from CWD for project version files. Nearest directory wins; within
# one directory, explicit .pvmrc wins over .php-version and composer.json.
pvm_find_project_version() {
  local dir="$PWD"
  while [ -n "$dir" ]; do
    if [ -f "$dir/$PVM_RC_FILE" ]; then
      pvm_normalize_version "$(cat "$dir/$PVM_RC_FILE")"
      return 0
    fi
    if [ -f "$dir/.php-version" ]; then
      pvm_constraint_to_version "$(cat "$dir/.php-version")" && return 0
    fi
    if [ -f "$dir/composer.json" ]; then
      pvm_php_from_composer "$dir/composer.json" && return 0
    fi
    [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")"
  done
  return 1
}

# Active version: $PVM_PHP_VERSION env > project version > global file.
pvm_resolve_version() {
  if [ -n "${PVM_PHP_VERSION:-}" ]; then
    pvm_normalize_version "$PVM_PHP_VERSION"; return 0
  fi
  if pvm_find_project_version; then return 0; fi
  if [ -f "$PVM_VERSION_FILE" ]; then
    pvm_normalize_version "$(cat "$PVM_VERSION_FILE")"; return 0
  fi
  return 1
}

pvm_set_global_version() {
  mkdir -p "$PVM_CONFIG_DIR"
  printf '%s' "$1" > "$PVM_VERSION_FILE"
}

# ---- Commands -------------------------------------------------------------

pvm_cmd_install() {
  local v="${1:-}"
  if [ -z "$v" ]; then
    v="$(pvm_find_project_version)" \
      || { pvm_lang_is_pt && pvm_die "uso: pvm install <version> (ou adicione $PVM_RC_FILE, .php-version ou composer.json require.php)" || pvm_die "usage: pvm install <version> (or add $PVM_RC_FILE, .php-version, or composer.json require.php)"; }
    pvm_lang_is_pt && pvm_info "Versao do projeto detectada -> $v" || pvm_info "Detected project version -> $v"
  fi
  pvm_require_docker
  v="$(pvm_normalize_version "$v")"
  pvm_pull_version "$v"
  pvm_lang_is_pt && pvm_ok "PHP $v instalado." || pvm_ok "PHP $v installed."
  if [ ! -f "$PVM_VERSION_FILE" ]; then
    pvm_set_global_version "$v"
    pvm_lang_is_pt && pvm_ok "Versao global do PHP definida para $v." || pvm_ok "Set global PHP version to $v."
  fi
}

pvm_cmd_uninstall() {
  [ $# -ge 1 ] || { pvm_lang_is_pt && pvm_die "uso: pvm uninstall <version>" || pvm_die "usage: pvm uninstall <version>"; }
  pvm_require_docker
  local v; v="$(pvm_normalize_version "$1")"
  pvm_image_present "$v" \
    || { pvm_lang_is_pt && pvm_die "PHP $v nao esta instalado." || pvm_die "PHP $v is not installed."; }
  docker image rm "$(pvm_image_for "$v")" >/dev/null \
    || { pvm_lang_is_pt && pvm_die "Nao foi possivel remover a imagem do PHP $v." || pvm_die "Could not remove image for PHP $v."; }
  pvm_lang_is_pt && pvm_ok "PHP $v removido." || pvm_ok "PHP $v uninstalled."
}

pvm_cmd_list() {
  local current; current="$(pvm_resolve_version 2>/dev/null || true)"
  local versions; versions="$(pvm_list_installed)"
  if [ -z "$versions" ]; then
    pvm_lang_is_pt && pvm_info "Nenhuma versao do PHP instalada. Rode: pvm install <version>" || pvm_info "No PHP versions installed. Run: pvm install <version>"
    return 0
  fi
  local v
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    if [ "$v" = "$current" ]; then
      printf '%s%s *%s\n' "$PVM_C_GRN" "$v" "$PVM_C_OFF"
    else
      printf '%s\n' "$v"
    fi
  done <<< "$versions"
}

pvm_cmd_available() {
  local installed; installed="$(pvm_list_installed)"
  local v
  for v in "${PVM_AVAILABLE_VERSIONS[@]}"; do
    if grep -qx "$v" <<< "$installed"; then
      printf '%s%s%s %s(installed)%s\n' "$PVM_C_GRN" "$v" "$PVM_C_OFF" "$PVM_C_DIM" "$PVM_C_OFF"
    else
      printf '%s\n' "$v"
    fi
  done
}

pvm_cmd_use() {
  local v="${1:-}"
  if [ -z "$v" ]; then
    v="$(pvm_find_project_version)" \
      || { pvm_lang_is_pt && pvm_die "Nenhuma versao informada e nenhuma versao de projeto encontrada ($PVM_RC_FILE, .php-version ou composer.json require.php)." || pvm_die "No version given and no project version found ($PVM_RC_FILE, .php-version, or composer.json require.php)."; }
    pvm_lang_is_pt && pvm_info "Versao do projeto detectada -> $v" || pvm_info "Detected project version -> $v"
  fi
  v="$(pvm_normalize_version "$v")"
  pvm_image_present "$v" \
    || { pvm_lang_is_pt && pvm_die "PHP $v nao esta instalado. Rode: pvm install $v" || pvm_die "PHP $v is not installed. Run: pvm install $v"; }
  pvm_set_global_version "$v"
  pvm_lang_is_pt && pvm_ok "Usando PHP $v." || pvm_ok "Now using PHP $v."
}

pvm_cmd_current() {
  local v
  if v="$(pvm_resolve_version)"; then
    printf '%s\n' "$v"
  else
    pvm_lang_is_pt && pvm_info "Nenhuma versao do PHP selecionada. Rode: pvm use <version>" || pvm_info "No PHP version selected. Run: pvm use <version>"
    return 1
  fi
}
