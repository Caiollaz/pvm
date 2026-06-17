#!/usr/bin/env bash
#
# Minimal pure-bash test suite for pvm's non-Docker logic
# (version normalization, project version resolution, list parsing).
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

check_fails() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  FAIL %s (command succeeded)\n' "$desc"; fail=$((fail+1))
  else
    printf '  ok   %s\n' "$desc"; pass=$((pass+1))
  fi
}

echo "normalize_version:"
check "plain"        "$(pvm_normalize_version '8.3')"        "8.3"
check "php- prefix"  "$(pvm_normalize_version 'php-8.2')"    "8.2"
check "whitespace"   "$(pvm_normalize_version '  8.1  ')"    "8.1"
check "newline"      "$(pvm_normalize_version $'8.4\n')"     "8.4"

echo "constraints:"
check "caret"        "$(pvm_constraint_to_version '^8.1')"       "8.1"
check "gte"          "$(pvm_constraint_to_version '>=8.2')"      "8.2"
check "tilde patch"  "$(pvm_constraint_to_version '~8.2.3')"     "8.2"
check "wildcard"     "$(pvm_constraint_to_version '8.1.*')"      "8.1"
check "plain minor"  "$(pvm_constraint_to_version '8.3')"        "8.3"
check "range first"  "$(pvm_constraint_to_version '>=8.1 <8.4')" "8.1"
check "patch"        "$(pvm_constraint_to_version '8.3.7')"      "8.3"
check_fails "major only fails" pvm_constraint_to_version "8"

echo "composer:"
composer_work="$(mktemp -d)"
cat > "$composer_work/composer.json" <<'JSON'
{
  "require": {
    "php": "^8.2",
    "phpunit/phpunit": "^10.0",
    "ext-json": "*"
  }
}
JSON
cat > "$composer_work/no-php.json" <<'JSON'
{
  "require": {
    "phpunit/phpunit": "^10.0"
  }
}
JSON
cat > "$composer_work/platform-before-require.json" <<'JSON'
{
  "config": {
    "platform": {
      "php": "8.1.0"
    }
  },
  "require": {
    "php": "^8.3"
  }
}
JSON
check "require.php" "$(pvm_php_from_composer "$composer_work/composer.json")" "8.2"
check "ignore config.platform.php" "$(pvm_php_from_composer "$composer_work/platform-before-require.json")" "8.3"
check_fails "missing require.php fails" pvm_php_from_composer "$composer_work/no-php.json"

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

project="$(mktemp -d)"; cd "$project"
cat > composer.json <<'JSON'
{
  "require": {
    "php": "^8.2"
  }
}
JSON
mkdir -p app; cd app
check "composer project version" "$(pvm_find_project_version)" "8.2"
check "composer resolves" "$(pvm_resolve_version)" "8.2"

cd "$project"
echo "8.3" > "$PVM_RC_FILE"
check "pvmrc beats composer same dir" "$(pvm_find_project_version)" "8.3"

php_version_work="$(mktemp -d)"; cd "$php_version_work"
echo ">=8.1" > .php-version
check ".php-version project version" "$(pvm_find_project_version)" "8.1"

nearest="$(mktemp -d)"; cd "$nearest"
cat > composer.json <<'JSON'
{
  "require": {
    "php": "^8.1"
  }
}
JSON
mkdir -p child/deep
cat > child/composer.json <<'JSON'
{
  "require": {
    "php": "^8.4"
  }
}
JSON
cd child/deep
check "nearest dir wins" "$(pvm_find_project_version)" "8.4"

cd "$ROOT"
echo
if [ "$fail" -eq 0 ]; then
  printf '%d passed, 0 failed\n' "$pass"
else
  printf '%d passed, %d FAILED\n' "$pass" "$fail"; exit 1
fi
