#!/usr/bin/env bash
#
# pvm installer.
#
#   curl -fsSL https://github.com/Caiollaz/pvm/releases/latest/download/install.sh | bash
#   wget -qO-  https://github.com/Caiollaz/pvm/releases/latest/download/install.sh | bash
#
# Pin a version:   PVM_VERSION=0.1.0 curl -fsSL .../install.sh | bash
# From a clone:    ./install.sh
#
# Steps: validate Docker, create directories, install scripts (from a local
# checkout or by downloading a release tarball), wire PATH, print next steps.
# Docker is the only runtime dependency; git is NOT required.

set -euo pipefail

PVM_DIR="${PVM_DIR:-$HOME/.pvm}"
PVM_BASE_URL="${PVM_BASE_URL:-https://github.com/Caiollaz/pvm}"
# PVM_VERSION (optional) pins a release, e.g. 0.1.0; empty = latest.
PVM_VERSION="${PVM_VERSION:-}"
# PVM_TARBALL (optional) overrides the source with a local path or URL
# (used for offline installs and CI tests).
PVM_TARBALL="${PVM_TARBALL:-}"

_red=$'\033[31m'; _grn=$'\033[32m'; _yel=$'\033[33m'; _blu=$'\033[34m'; _off=$'\033[0m'
say()  { printf '%spvm-install:%s %s\n' "$_blu" "$_off" "$*"; }
ok()   { printf '%spvm-install:%s %s\n' "$_grn" "$_off" "$*"; }
warn() { printf '%spvm-install:%s %s\n' "$_yel" "$_off" "$*" >&2; }
die()  { printf '%spvm-install:%s %s\n' "$_red" "$_off" "$*" >&2; exit 1; }

install_lang_is_pt() {
  case "${PVM_LANG:-pt}" in
    en|en_US|en-US|english|English) return 1 ;;
    *) return 0 ;;
  esac
}

host_os() {
  case "$(uname -s 2>/dev/null || printf unknown)" in
    Darwin*) printf 'macos' ;;
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then printf 'wsl'; else printf 'linux'; fi
      ;;
    MINGW*|MSYS*|CYGWIN*) printf 'windows' ;;
    *) printf 'unknown' ;;
  esac
}

docker_install_hint() {
  case "$(host_os)" in
    windows|wsl)
      if install_lang_is_pt; then
        printf '%s\n%s\n%s\n%s\n' \
          "Bora instalar o Docker Desktop primeiro. No PowerShell como Administrador, rode:" \
          "  choco install docker-desktop -y" \
          "Depois abra o Docker Desktop e reinicie o terminal." \
          "Ainda nao tem Chocolatey? Instale por aqui: https://chocolatey.org/install"
      else
        printf '%s\n%s\n%s\n%s\n' \
          "Let's install Docker Desktop first. From an Administrator PowerShell, run:" \
          "  choco install docker-desktop -y" \
          "Then open Docker Desktop and restart your terminal." \
          "No Chocolatey yet? Install it here: https://chocolatey.org/install"
      fi
      ;;
    *)
      install_lang_is_pt && printf '%s\n%s\n' "Bora instalar o Docker primeiro:" "  https://docs.docker.com/get-docker/" || printf '%s\n%s\n' "Let's install Docker first:" "  https://docs.docker.com/get-docker/"
      ;;
  esac
}

# 1. Validate Docker (warn only — install can proceed, but pvm needs it).
if command -v docker >/dev/null 2>&1; then
  install_lang_is_pt && ok "Docker encontrado: $(docker --version)" || ok "Docker found: $(docker --version)"
else
  install_lang_is_pt && warn "Opa, ainda nao encontrei o Docker. curl/wget instalam so o PVM; para rodar PHP, o PVM ainda precisa do Docker." || warn "Docker was not found yet. curl/wget install PVM only; PVM still needs Docker to run PHP."
  docker_install_hint >&2
fi

# 2. Create directories.
install_lang_is_pt && say "Criando os arquivos do PVM em $PVM_DIR ..." || say "Creating directories under $PVM_DIR ..."
mkdir -p "$PVM_DIR/bin" "$PVM_DIR/src" "$PVM_DIR/images" "$PVM_DIR/config"

# 3. Install scripts — from a local checkout, else download a release tarball.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

copy_tree() {
  local from="$1"
  cp "$from"/bin/pvm "$from"/bin/php "$from"/bin/composer "$PVM_DIR/bin/"
  cp "$from"/src/*.sh "$PVM_DIR/src/"
}

# Download $1 to file $2 using curl or wget (whichever is present).
fetch() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    die "Need curl or wget to download $url"
  fi
}

# Best-effort SHA256 verification of $1 against a SHA256SUMS file in $2.
verify_checksum() {
  local file="$1" sums="$2" tool="" name expected actual
  if command -v sha256sum >/dev/null 2>&1; then tool="sha256sum";
  elif command -v shasum >/dev/null 2>&1; then tool="shasum -a 256"; fi
  if [ -z "$tool" ]; then
    warn "No sha256 tool found — skipping checksum verification."
    return 0
  fi
  name="$(basename "$file")"
  expected="$(awk -v n="$name" '$2==n || $2=="*"n {print $1}' "$sums" | head -n1)"
  if [ -z "$expected" ]; then
    warn "No checksum entry for $name — skipping verification."
    return 0
  fi
  actual="$($tool "$file" | awk '{print $1}')"
  [ "$actual" = "$expected" ] || die "Checksum mismatch for $name (got $actual, expected $expected)."
  ok "Checksum verified ($name)."
}

resolve_tarball_url() {
  if [ -n "$PVM_TARBALL" ]; then
    printf '%s' "$PVM_TARBALL"
  elif [ -n "$PVM_VERSION" ]; then
    printf '%s/releases/download/v%s/pvm-%s.tar.gz' "$PVM_BASE_URL" "$PVM_VERSION" "$PVM_VERSION"
  else
    printf '%s/releases/latest/download/pvm.tar.gz' "$PVM_BASE_URL"
  fi
}

if [ -f "$SCRIPT_DIR/bin/pvm" ] && [ -d "$SCRIPT_DIR/src" ]; then
  say "Installing from local checkout ($SCRIPT_DIR)..."
  copy_tree "$SCRIPT_DIR"
else
  url="$(resolve_tarball_url)"
  tmp="$(mktemp -d)"
  tarball="$tmp/pvm.tar.gz"
  say "Downloading $url ..."
  if [ -n "$PVM_TARBALL" ] && [ -f "$PVM_TARBALL" ]; then
    cp "$PVM_TARBALL" "$tarball"            # local path override
  else
    fetch "$url" "$tarball" || die "Download failed: $url"
    # Verify against SHA256SUMS published next to the asset (best-effort).
    sums_url="${url%/*}/SHA256SUMS"
    if fetch "$sums_url" "$tmp/SHA256SUMS" 2>/dev/null; then
      verify_checksum "$tarball" "$tmp/SHA256SUMS"
    else
      warn "Could not fetch SHA256SUMS — skipping checksum verification."
    fi
  fi
  tar -xzf "$tarball" -C "$tmp" || die "Could not extract tarball."
  # The tarball wraps everything in a top-level pvm/ directory.
  src_root="$tmp/pvm"
  [ -f "$src_root/bin/pvm" ] || src_root="$(dirname "$(find "$tmp" -type f -name pvm -path '*/bin/pvm' | head -n1)")/.."
  [ -f "$src_root/bin/pvm" ] || die "Unexpected tarball layout (bin/pvm not found)."
  copy_tree "$src_root"
  rm -rf "$tmp"
fi

chmod +x "$PVM_DIR"/bin/pvm "$PVM_DIR"/bin/php "$PVM_DIR"/bin/composer

# 4. Wire PATH into shell rc files.
PATH_LINE='export PATH="$HOME/.pvm/bin:$PATH"'
MARKER='# pvm'

# Write the PATH line to $rc, creating the file if it doesn't exist yet.
add_to_rc() {
  local rc="$1"
  grep -qF "$MARKER" "$rc" 2>/dev/null && return 0
  { printf '\n%s\n%s\n' "$MARKER" "$PATH_LINE"; } >> "$rc"
  ok "Updated $rc"
}

# rc file for the user's current login shell — created even when absent so the
# pvm command is always wired up, not just when a shell rc already exists.
default_rc_for_shell() {
  case "$(basename "${SHELL:-}")" in
    zsh)  printf '%s' "$HOME/.zshrc" ;;
    bash) printf '%s' "$HOME/.bashrc" ;;
    *)    printf '%s' "$HOME/.profile" ;;
  esac
}

updated=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  if [ -e "$rc" ]; then add_to_rc "$rc"; updated=1; fi
done

# No rc file existed: create the one matching the current shell.
if [ "$updated" -eq 0 ]; then
  rc="$(default_rc_for_shell)"
  add_to_rc "$rc"
  updated=1
fi

# Make pvm available in the current session too, so it works without a restart.
export PATH="$HOME/.pvm/bin:$PATH"

# 5. Final instructions.
echo
install_lang_is_pt && ok "pvm instalado em $PVM_DIR" || ok "pvm installed to $PVM_DIR"
echo
install_lang_is_pt && say "Reinicie o terminal ou rode:" || say "Restart your shell or run:"
echo "  $PATH_LINE"
echo
install_lang_is_pt && say "Bora testar:" || say "Then get started:"
echo "  pvm install 8.3"
echo "  pvm use 8.3"
echo "  php -v"
echo "  composer -V"
