#!/usr/bin/env bash
#
# pvm installer.
#
#   curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/pvm/main/install.sh | bash
#   wget -qO-  https://raw.githubusercontent.com/YOUR_GITHUB_USER/pvm/main/install.sh | bash
#
# or from a clone:
#
#   ./install.sh
#
# Steps: create directories, install scripts, wire PATH, validate Docker,
# print next steps. Docker is the only runtime dependency.

set -euo pipefail

PVM_DIR="${PVM_DIR:-$HOME/.pvm}"
PVM_REPO="${PVM_REPO:-https://github.com/YOUR_GITHUB_USER/pvm}"
PVM_BRANCH="${PVM_BRANCH:-main}"

_red=$'\033[31m'; _grn=$'\033[32m'; _yel=$'\033[33m'; _blu=$'\033[34m'; _off=$'\033[0m'
say()  { printf '%spvm-install:%s %s\n' "$_blu" "$_off" "$*"; }
ok()   { printf '%spvm-install:%s %s\n' "$_grn" "$_off" "$*"; }
warn() { printf '%spvm-install:%s %s\n' "$_yel" "$_off" "$*" >&2; }
die()  { printf '%spvm-install:%s %s\n' "$_red" "$_off" "$*" >&2; exit 1; }

# 1. Validate Docker (warn only — install can proceed, but pvm needs it).
if command -v docker >/dev/null 2>&1; then
  ok "Docker found: $(docker --version)"
else
  warn "Docker not found. pvm requires Docker at runtime: https://docs.docker.com/get-docker/"
fi

# 2. Create directories.
say "Creating directories under $PVM_DIR ..."
mkdir -p "$PVM_DIR/bin" "$PVM_DIR/src" "$PVM_DIR/images" "$PVM_DIR/config"

# 3. Install scripts — from a local checkout, else clone the repo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

copy_tree() {
  local from="$1"
  cp "$from"/bin/pvm "$from"/bin/php "$from"/bin/composer "$PVM_DIR/bin/"
  cp "$from"/src/*.sh "$PVM_DIR/src/"
}

if [ -f "$SCRIPT_DIR/bin/pvm" ] && [ -d "$SCRIPT_DIR/src" ]; then
  say "Installing from local checkout ($SCRIPT_DIR)..."
  copy_tree "$SCRIPT_DIR"
else
  command -v git >/dev/null 2>&1 || die "git is required to clone $PVM_REPO"
  say "Cloning $PVM_REPO ($PVM_BRANCH)..."
  tmp="$(mktemp -d)"
  git clone --depth 1 --branch "$PVM_BRANCH" "$PVM_REPO" "$tmp" >/dev/null 2>&1 \
    || die "Clone failed: $PVM_REPO"
  copy_tree "$tmp"
  rm -rf "$tmp"
fi

chmod +x "$PVM_DIR"/bin/pvm "$PVM_DIR"/bin/php "$PVM_DIR"/bin/composer

# 4. Wire PATH into shell rc files.
PATH_LINE='export PATH="$HOME/.pvm/bin:$PATH"'
MARKER='# pvm'

add_to_rc() {
  local rc="$1"
  [ -e "$rc" ] || return 0
  grep -qF "$MARKER" "$rc" 2>/dev/null && return 0
  { printf '\n%s\n%s\n' "$MARKER" "$PATH_LINE"; } >> "$rc"
  ok "Updated $rc"
}

updated=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  if [ -e "$rc" ]; then add_to_rc "$rc"; updated=1; fi
done
[ "$updated" -eq 1 ] || warn "No shell rc found. Add manually:  $PATH_LINE"

# 5. Final instructions.
echo
ok "pvm installed to $PVM_DIR"
echo
say "Restart your shell or run:"
echo "  $PATH_LINE"
echo
say "Then get started:"
echo "  pvm install 8.3"
echo "  pvm use 8.3"
echo "  php -v"
echo "  composer -V"
