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

pvm_host_os() {
  case "$(uname -s 2>/dev/null || printf unknown)" in
    Darwin*) printf 'macos' ;;
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then printf 'wsl'; else printf 'linux'; fi
      ;;
    MINGW*|MSYS*|CYGWIN*) printf 'windows' ;;
    *) printf 'unknown' ;;
  esac
}

pvm_docker_install_hint() {
  case "$(pvm_host_os)" in
    windows)
      if pvm_lang_is_pt; then cat <<'EOF'
Bora instalar o Docker Desktop primeiro. No PowerShell como Administrador, rode:
  choco install docker-desktop -y

Depois abra o Docker Desktop e reinicie o terminal.
Ainda nao tem Chocolatey? Instale por aqui: https://chocolatey.org/install
EOF
      else cat <<'EOF'
Let's install Docker Desktop first. From an Administrator PowerShell, run:
  choco install docker-desktop -y

Then open Docker Desktop and restart your terminal.
No Chocolatey yet? Install it here: https://chocolatey.org/install
EOF
      fi
      ;;
    wsl)
      if pvm_lang_is_pt; then cat <<'EOF'
Bora instalar o Docker Desktop no Windows e ligar a integracao com o WSL.
No PowerShell como Administrador, rode:
  choco install docker-desktop -y

Depois abra Docker Desktop -> Settings -> Resources -> WSL Integration.
EOF
      else cat <<'EOF'
Let's install Docker Desktop on Windows and enable WSL integration for this distro.
From an Administrator PowerShell, run:
  choco install docker-desktop -y

Then open Docker Desktop -> Settings -> Resources -> WSL Integration.
EOF
      fi
      ;;
    macos)
      if pvm_lang_is_pt; then cat <<'EOF'
Bora instalar o Docker Desktop primeiro:
  https://docs.docker.com/desktop/setup/install/mac-install/

Depois abra o Docker Desktop e espere ele ficar "running".
EOF
      else cat <<'EOF'
Let's install Docker Desktop first:
  https://docs.docker.com/desktop/setup/install/mac-install/

Then open Docker Desktop and wait until it says "running".
EOF
      fi
      ;;
    linux)
      if pvm_lang_is_pt; then cat <<'EOF'
Bora instalar o Docker Engine primeiro:
  https://docs.docker.com/engine/install/

Depois inicie o Docker, por exemplo:
  sudo systemctl start docker
EOF
      else cat <<'EOF'
Let's install Docker Engine first:
  https://docs.docker.com/engine/install/

Then start Docker, for example:
  sudo systemctl start docker
EOF
      fi
      ;;
    *)
      if pvm_lang_is_pt; then cat <<'EOF'
Bora instalar o Docker primeiro:
  https://docs.docker.com/get-docker/
EOF
      else cat <<'EOF'
Let's install Docker first:
  https://docs.docker.com/get-docker/
EOF
      fi
      ;;
  esac
}

pvm_docker_start_hint() {
  case "$(pvm_host_os)" in
    windows|macos)
      pvm_lang_is_pt && printf '%s\n' 'Abra o Docker Desktop, espere ele ficar "running" e tente de novo.' || printf '%s\n' 'Open Docker Desktop, wait until it says "running", then try again.'
      ;;
    wsl)
      if pvm_lang_is_pt; then
        printf '%s\n%s\n' 'Abra o Docker Desktop no Windows e confira se a integracao WSL esta ligada para esta distro.' 'Depois reinicie este terminal WSL e tente de novo.'
      else
        printf '%s\n%s\n' 'Open Docker Desktop on Windows and make sure WSL integration is enabled for this distro.' 'Then restart this WSL terminal and try again.'
      fi
      ;;
    linux)
      if pvm_lang_is_pt; then cat <<'EOF'
Inicie o Docker e garanta que seu usuario consegue acessa-lo:
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"

Depois de mudar grupos, faca logout e login de novo.
EOF
      else cat <<'EOF'
Start Docker and make sure your user can access it:
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"

After changing groups, log out and back in.
EOF
      fi
      ;;
    *)
      pvm_lang_is_pt && printf '%s\n%s\n' 'Inicie o Docker e confira se este terminal consegue rodar:' '  docker info' || printf '%s\n%s\n' 'Start Docker and make sure this terminal can run:' '  docker info'
      ;;
  esac
}

pvm_require_docker() {
  if ! pvm_docker_installed; then
    if pvm_lang_is_pt; then
      pvm_err "Opa, ainda nao encontrei o Docker."
      pvm_log "PVM usa Docker para rodar PHP. curl/wget instalam so o PVM, nao o Docker."
    else
      pvm_err "Docker was not found yet."
      pvm_log "PVM uses Docker to run PHP. curl/wget install PVM only, not Docker."
    fi
    pvm_log "$(pvm_docker_install_hint)"
    exit 1
  fi
  if ! pvm_docker_running; then
    pvm_lang_is_pt && pvm_err "Docker esta instalado, mas nao esta rodando ou este usuario nao consegue acessa-lo." || pvm_err "Docker is installed, but it is not running or this user cannot access it."
    pvm_log "$(pvm_docker_start_hint)"
    exit 1
  fi
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
    pvm_lang_is_pt && pvm_ok "PHP $v ja esta instalado (imagem $image em cache)." || pvm_ok "PHP $v already installed (image $image cached)."
    return 0
  fi
  pvm_lang_is_pt && pvm_info "Baixando $image ..." || pvm_info "Pulling $image ..."
  docker pull "$image" || { pvm_lang_is_pt && pvm_die "Falha ao baixar. O PHP $v existe no Docker Hub ($image)?" || pvm_die "Pull failed. Does PHP $v exist on Docker Hub ($image)?"; }
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
    || { pvm_lang_is_pt && pvm_die "Nenhuma versao do PHP selecionada. Rode 'pvm use <version>' ou adicione $PVM_RC_FILE, .php-version ou composer.json." || pvm_die "No PHP version selected. Run 'pvm use <version>' or add $PVM_RC_FILE, .php-version, or composer.json."; }
  pvm_image_present "$v" \
    || { pvm_lang_is_pt && pvm_die "PHP $v nao esta instalado. Rode: pvm install $v" || pvm_die "PHP $v is not installed. Run: pvm install $v"; }

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
    || { pvm_lang_is_pt && pvm_die "Nenhuma versao do PHP selecionada. Rode 'pvm use <version>' primeiro." || pvm_die "No PHP version selected. Run 'pvm use <version>' first."; }
  pvm_image_present "$v" \
    || { pvm_lang_is_pt && pvm_die "PHP $v nao esta instalado. Rode: pvm install $v" || pvm_die "PHP $v is not installed. Run: pvm install $v"; }

  pvm_lang_is_pt && pvm_info "Baixando Composer (primeira vez; depois fica em cache)..." || pvm_info "Fetching Composer (first run, cached afterwards)..."
  mkdir -p "$PVM_DIR"
  local image; image="$(pvm_image_for "$v")"
  docker run --rm -v "$PVM_DIR":/pvm -w /pvm "$image" \
    php -r "copy('https://getcomposer.org/installer', '/pvm/composer-setup.php');" \
    || { pvm_lang_is_pt && pvm_die "Nao foi possivel baixar o instalador do Composer." || pvm_die "Could not download the Composer installer."; }
  docker run --rm -v "$PVM_DIR":/pvm -w /pvm "$image" \
    php composer-setup.php --install-dir=/pvm --filename=composer.phar --quiet \
    || { pvm_lang_is_pt && pvm_die "Instalacao do Composer falhou." || pvm_die "Composer installation failed."; }
  rm -f "$PVM_DIR/composer-setup.php"
  pvm_lang_is_pt && pvm_ok "Composer pronto." || pvm_ok "Composer ready."
}

# Run `composer "$@"` in the active container with a persistent cache.
pvm_exec_composer() {
  pvm_require_docker
  local v; v="$(pvm_resolve_version)" \
    || { pvm_lang_is_pt && pvm_die "Nenhuma versao do PHP selecionada. Rode 'pvm use <version>' ou adicione $PVM_RC_FILE, .php-version ou composer.json." || pvm_die "No PHP version selected. Run 'pvm use <version>' or add $PVM_RC_FILE, .php-version, or composer.json."; }
  pvm_image_present "$v" \
    || { pvm_lang_is_pt && pvm_die "PHP $v nao esta instalado. Rode: pvm install $v" || pvm_die "PHP $v is not installed. Run: pvm install $v"; }
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
