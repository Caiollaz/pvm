#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
#
# config.sh — paths, constants and defaults shared across pvm.

[ -n "${_PVM_CONFIG_LOADED:-}" ] && return 0
_PVM_CONFIG_LOADED=1

# pvm's own version.
PVM_VERSION="0.2.0"

# Data directory (state lives here). Overridable for tests / custom installs.
: "${PVM_DIR:=$HOME/.pvm}"

PVM_BIN_DIR="$PVM_DIR/bin"
PVM_SRC_DIR="$PVM_DIR/src"
PVM_IMAGES_DIR="$PVM_DIR/images"
PVM_CONFIG_DIR="$PVM_DIR/config"

# File holding the active global version.
PVM_VERSION_FILE="$PVM_CONFIG_DIR/version"

# File holding the preferred terminal language (pt or en).
PVM_LANG_FILE="$PVM_CONFIG_DIR/lang"

# Per-project version file (like .nvmrc).
PVM_RC_FILE=".pvmrc"

# Cached Composer phar (fetched once, runs inside the PHP container).
PVM_COMPOSER_PHAR="$PVM_DIR/composer.phar"

# Official Docker image template. %s = version.
PVM_PHP_IMAGE_TPL="php:%s-cli"

# Versions advertised by `pvm available`.
PVM_AVAILABLE_VERSIONS=(8.1 8.2 8.3 8.4)

# Host Composer cache, mounted into the container.
: "${PVM_COMPOSER_CACHE:=$HOME/.composer/cache}"
