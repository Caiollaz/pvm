#!/usr/bin/env bash
#
# Minimal pure-bash test suite for pvm's non-Docker logic
# (version normalization, .pvmrc resolution, list parsing).
#
# Run: ./tests/test_pvm.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PVM_DIR; PVM_DIR="$(mktemp -d)/.pvm"
mkdir -p "$PVM_DIR/config"

# shellcheck source=../src/config.sh
. "$ROOT/src/config.sh"
# shellcheck source=../src/utils.sh
. "$ROOT/src/utils.sh"
# shellcheck source=../src/versions.sh
. "$ROOT/src/versions.sh"

pass=0; fail=0
check() {
  local desc="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    printf '  ok   %s\n' "$desc"; pass=$((pass+1))
  else
    printf '  FAIL %s (got=%q want=%q)\n' "$desc" "$got" "$want"; fail=$((fail+1))
  fi
}

echo "normalize_version:"
check "plain"        "$(pvm_normalize_version '8.3')"        "8.3"
check "php- prefix"  "$(pvm_normalize_version 'php-8.2')"    "8.2"
check "whitespace"   "$(pvm_normalize_version '  8.1  ')"    "8.1"
check "newline"      "$(pvm_normalize_version $'8.4\n')"     "8.4"

echo "resolution:"
work="$(mktemp -d)"; cd "$work"

# global only
pvm_set_global_version "8.1"
check "global"       "$(pvm_resolve_version)"               "8.1"

# .pvmrc overrides global
echo "8.3" > "$work/$PVM_RC_FILE"
check "pvmrc > global" "$(pvm_resolve_version)"             "8.3"

# nested dir finds parent .pvmrc
mkdir -p "$work/sub/deep"; cd "$work/sub/deep"
check "pvmrc up-tree" "$(pvm_resolve_version)"              "8.3"

# env var wins over everything
check "env wins"     "$(PVM_PHP_VERSION=8.4 pvm_resolve_version)" "8.4"

cd "$ROOT"
echo
if [ "$fail" -eq 0 ]; then
  printf '%d passed, 0 failed\n' "$pass"
else
  printf '%d passed, %d FAILED\n' "$pass" "$fail"; exit 1
fi
