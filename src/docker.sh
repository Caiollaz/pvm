#!/usr/bin/env bash
# shellcheck shell=bash
#
# docker.sh — all Docker interaction: checks, image management, runners.

[ -n "${_PVM_DOCKER_LOADED:-}" ] && return 0
_PVM_DOCKER_LOADED=1

# Resolve the official image tag for a version.
pvm_image_for() {
  # shellcheck disable=SC2059
  printf "$PVM_PHP_IMAGE_TPL" "$1"
}

pvm_docker_installed() { command -v docker >/dev/null 2>&1; }
pvm_docker_running()   { docker info >/dev/null 2>&1; }

pvm_require_docker() {
  pvm_docker_installed || pvm_die "Docker not found. Install it: https://docs.docker.com/get-docker/"
  pvm_docker_running   || pvm_die "Docker daemon not running or not accessible by this user."
}

# True when the image for a version is already present locally (avoids re-pull).
pvm_image_present() {
  docker image inspect "$(pvm_image_for "$1")" >/dev/null 2>&1
}

# Pull a version image unless cached.
pvm_pull_version() {
  local v="$1" image
  image="$(pvm_image_for "$v")"
  if pvm_image_present "$v"; then
    pvm_ok "PHP $v already installed (image $image cached)."
    return 0
  fi
  pvm_info "Pulling $image ..."
  docker pull "$image" || pvm_die "Pull failed. Does PHP $v exist on Docker Hub ($image)?"
}

# Shared docker run flags: TTY when interactive, UID/GID map on Linux.
pvm_run_flags() {
  PVM_RUN_FLAGS=(-i)
  pvm_has_tty && PVM_RUN_FLAGS=(-i -t)
  if [ "$(uname -s)" = "Linux" ]; then
    PVM_RUN_FLAGS+=(-u "$(id -u):$(id -g)")
  fi
}

# Run `php "$@"` in the active version's container with CWD mounted.
pvm_exec_php() {
  pvm_require_docker
  local v; v="$(pvm_resolve_version)" \
    || pvm_die "No PHP version selected. Run 'pvm use <version>' or add a $PVM_RC_FILE file."
  pvm_image_present "$v" || pvm_die "PHP $v is not installed. Run: pvm install $v"

  pvm_run_flags
  exec docker run --rm "${PVM_RUN_FLAGS[@]}" \
    -v "$PWD":/app -w /app \
    -e HOME=/tmp \
    "$(pvm_image_for "$v")" php "$@"
}

# Download composer.phar once, using the PHP container itself (no host deps).
pvm_ensure_composer() {
  [ -f "$PVM_COMPOSER_PHAR" ] && return 0
  local v; v="$(pvm_resolve_version)" \
    || pvm_die "No PHP version selected. Run 'pvm use <version>' first."
  pvm_image_present "$v" || pvm_die "PHP $v is not installed. Run: pvm install $v"

  pvm_info "Fetching Composer (first run, cached afterwards)..."
  mkdir -p "$PVM_DIR"
  local image; image="$(pvm_image_for "$v")"
  docker run --rm -v "$PVM_DIR":/pvm -w /pvm "$image" \
    php -r "copy('https://getcomposer.org/installer', '/pvm/composer-setup.php');" \
    || pvm_die "Could not download the Composer installer."
  docker run --rm -v "$PVM_DIR":/pvm -w /pvm "$image" \
    php composer-setup.php --install-dir=/pvm --filename=composer.phar --quiet \
    || pvm_die "Composer installation failed."
  rm -f "$PVM_DIR/composer-setup.php"
  pvm_ok "Composer ready."
}

# Run `composer "$@"` in the active container with a persistent cache.
pvm_exec_composer() {
  pvm_require_docker
  local v; v="$(pvm_resolve_version)" \
    || pvm_die "No PHP version selected. Run 'pvm use <version>' or add a $PVM_RC_FILE file."
  pvm_image_present "$v" || pvm_die "PHP $v is not installed. Run: pvm install $v"
  pvm_ensure_composer
  mkdir -p "$PVM_COMPOSER_CACHE"

  pvm_run_flags
  exec docker run --rm "${PVM_RUN_FLAGS[@]}" \
    -v "$PWD":/app -w /app \
    -v "$PVM_COMPOSER_PHAR":/usr/local/bin/composer:ro \
    -v "$PVM_COMPOSER_CACHE":/tmp/composer-cache \
    -e HOME=/tmp \
    -e COMPOSER_CACHE_DIR=/tmp/composer-cache \
    "$(pvm_image_for "$v")" php /usr/local/bin/composer "$@"
}

# Installed versions, newest last (used by `pvm list`).
pvm_list_installed() {
  docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
    | awk -F: '$1=="php" && $2 ~ /-cli$/ { sub(/-cli$/,"",$2); print $2 }' \
    | sort -V
}
