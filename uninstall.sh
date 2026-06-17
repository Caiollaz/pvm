#!/usr/bin/env bash
#
# pvm uninstaller. Removes $PVM_DIR and the PATH lines added by install.sh.
# Does NOT remove pulled Docker images — use `pvm uninstall <version>` or
# `docker image rm php:<version>-cli` for those.

set -euo pipefail

PVM_DIR="${PVM_DIR:-$HOME/.pvm}"
MARKER='# pvm'

_red=$'\033[31m'; _grn=$'\033[32m'; _yel=$'\033[33m'; _blu=$'\033[34m'; _off=$'\033[0m'
say()  { printf '%spvm-uninstall:%s %s\n' "$_blu" "$_off" "$*"; }
ok()   { printf '%spvm-uninstall:%s %s\n' "$_grn" "$_off" "$*"; }
warn() { printf '%spvm-uninstall:%s %s\n' "$_yel" "$_off" "$*" >&2; }

uninstall_lang_is_pt() {
  case "${PVM_LANG:-pt}" in
    en|en_US|en-US|english|English) return 1 ;;
    *) return 0 ;;
  esac
}

# Remove the "# pvm" marker line and the PATH line that follows it.
strip_rc() {
  local rc="$1"
  [ -e "$rc" ] || return 0
  grep -qF "$MARKER" "$rc" 2>/dev/null || return 0
  local tmp; tmp="$(mktemp)"
  awk -v m="$MARKER" '
    $0 == m { skip = 1; next }
    skip == 1 && $0 ~ /\.pvm\/bin/ { skip = 0; next }
    skip == 1 { skip = 0 }
    { print }
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
  uninstall_lang_is_pt && ok "$rc limpo" || ok "Cleaned $rc"
}

if [ -d "$PVM_DIR" ]; then
  rm -rf "$PVM_DIR"
  uninstall_lang_is_pt && ok "$PVM_DIR removido" || ok "Removed $PVM_DIR"
else
  uninstall_lang_is_pt && warn "$PVM_DIR nao encontrado." || warn "$PVM_DIR not found."
fi

for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  strip_rc "$rc"
done

echo
uninstall_lang_is_pt && say "pvm desinstalado. Reinicie o terminal para atualizar o PATH." || say "pvm uninstalled. Restart your shell to refresh PATH."
uninstall_lang_is_pt && say "As imagens PHP baixadas ficaram no Docker. Liste com: docker images php" || say "Pulled PHP images were left in place. List them with: docker images php"
