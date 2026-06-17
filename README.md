# PVM — PHP Version Manager

> Use any version of PHP on your computer **without installing PHP**.
> If you can run one command, you can use PVM.

PHP normally has to be installed and configured on your machine, and switching
between versions (8.1, 8.2, 8.3…) is painful. PVM removes all of that. You pick
a version with one command, and then `php` and `composer` just work — exactly
like they would if PHP were installed, except nothing is actually installed on
your computer. It all runs inside Docker, behind the scenes.

```bash
pvm install 8.3
pvm use 8.3
php -v          # → PHP 8.3.x
```

Free and open source under the [MIT License](LICENSE).

---

## Contents

- [Who is this for](#who-is-this-for)
- [What you need before starting](#what-you-need-before-starting)
- [Install PVM](#install-pvm)
- [Your first commands (step by step)](#your-first-commands-step-by-step)
- [Everyday use](#everyday-use)
- [Pin a version per project (.pvmrc)](#pin-a-version-per-project-pvmrc)
- [All commands](#all-commands)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [For curious / advanced users](#for-curious--advanced-users)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Who is this for

Anyone who needs to run PHP — a Laravel app, a WordPress site, a script, a
tutorial you're following — and doesn't want to spend an afternoon installing
and configuring PHP, Composer, and extensions. You do **not** need to understand
Docker, containers, or how any of this works. Follow the steps and it works.

You will **never** have to:

- Install PHP
- Install Composer
- Configure versions by hand
- Set up aliases

## What you need before starting

Just one thing: **Docker**.

Docker is a free program that runs small, isolated environments on your
computer. PVM uses it as the engine that actually runs PHP — so you install
Docker once and never think about it again.

1. Install Docker Desktop (Windows / macOS) or Docker Engine (Linux):
   👉 https://docs.docker.com/get-docker/
2. Open it so it's running (on Windows/macOS you'll see the Docker whale icon).
3. Check it works by opening your terminal and running:

   ```bash
   docker --version
   ```

   If you see something like `Docker version 27.x.x`, you're ready. If you see
   "command not found", Docker isn't installed yet — go back to step 1.

> **What's a terminal?** It's the text window where you type commands.
> On macOS open **Terminal**, on Windows open **PowerShell** or **WSL**, on
> Linux open your **Terminal** app.

## Install PVM

Copy this line, paste it into your terminal, and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/pvm/main/install.sh | bash
```

Don't have `curl`? Use this instead:

```bash
wget -qO- https://raw.githubusercontent.com/YOUR_GITHUB_USER/pvm/main/install.sh | bash
```

When it finishes, **close your terminal and open a new one** (this lets your
computer find the new `pvm` command). To check it worked:

```bash
pvm version
```

You should see something like `pvm 0.1.0`.

<details>
<summary>Prefer to install from the source code instead?</summary>

```bash
git clone https://github.com/YOUR_GITHUB_USER/pvm
cd pvm
./install.sh
```
</details>

## Your first commands (step by step)

**1. Download a PHP version.** Let's use 8.3:

```bash
pvm install 8.3
```

The first time, this downloads PHP 8.3 (it may take a minute). You'll see
progress, then `PHP 8.3 installed.`

**2. Tell PVM to use it:**

```bash
pvm use 8.3
```

**3. That's it — use PHP normally:**

```bash
php -v
```

You should see `PHP 8.3.x …`. 🎉 You're running PHP without installing PHP.

Composer (PHP's package manager) is included too:

```bash
composer -V
```

## Everyday use

Once a version is active, type commands exactly like you would with a normal
PHP install — PVM handles the rest:

```bash
php artisan serve         # run a Laravel dev server
php artisan migrate       # run database migrations
php artisan test          # run tests
composer install          # install a project's dependencies
composer require guzzlehttp/guzzle   # add a package
phpunit                   # run PHPUnit
```

Need a different version later? Install it and switch:

```bash
pvm install 8.2
pvm use 8.2
```

See what you have installed:

```bash
pvm list
```

```text
8.2
8.3 *      ← the * marks the version you're using
```

## Pin a version per project (.pvmrc)

Different projects often need different PHP versions. Put a small file named
`.pvmrc` in a project folder with the version inside:

```bash
echo "8.2" > .pvmrc
```

Now whenever you're in that folder (or any folder inside it), `php` and
`composer` automatically use 8.2 — no need to run `pvm use` every time. This is
the same idea as `.nvmrc` if you've used Node before.

## All commands

| Command | What it does |
| --- | --- |
| `pvm install <version>` | Download a PHP version (e.g. `pvm install 8.3`) |
| `pvm uninstall <version>` | Remove a PHP version |
| `pvm list` | Show installed versions (`*` = the one in use) |
| `pvm available` | Show versions you can install |
| `pvm use [<version>]` | Choose the active version (no version → read `.pvmrc`) |
| `pvm current` | Show which version is active |
| `pvm doctor` | Check that everything is set up correctly |
| `pvm version` | Show PVM's own version |
| `pvm help` | Show help |

A more detailed reference lives in [docs/commands.md](docs/commands.md).

## Troubleshooting

**`pvm: command not found` right after installing**
Close your terminal and open a new one. If it still fails, run this once and try
again:

```bash
export PATH="$HOME/.pvm/bin:$PATH"
```

**`Docker daemon not running` / `Cannot connect to the Docker daemon`**
Docker isn't started. Open Docker Desktop (Windows/macOS) and wait for it to
say "running", or start it on Linux with `sudo systemctl start docker`.

**Not sure what's wrong? Ask PVM to check itself:**

```bash
pvm doctor
```

It checks Docker, your setup, and the active version, and tells you exactly
what to fix.

**Permission errors on Linux when running `docker`**
Add your user to the `docker` group (then log out and back in):

```bash
sudo usermod -aG docker "$USER"
```

## FAQ

**Do I need PHP or Composer installed?** No. Only Docker.

**Is it slow?** Only the *first* time you install a version (it downloads once)
and the first `composer` command (it sets up once). After that it's cached and
fast.

**Will it mess up my computer?** No. Nothing is installed system-wide. Removing
a version is just `pvm uninstall`, and removing PVM is deleting one folder.

**Does my Laravel / Symfony / WordPress project work?** Yes — run
`php artisan …`, `composer …`, `phpunit`, etc. as usual.

**macOS, Windows (WSL2), and Linux?** All supported.

## For curious / advanced users

**How it works.** `pvm install 8.3` runs `docker pull php:8.3-cli`. The active
version is stored in `~/.pvm/config/version` (or per-project in `.pvmrc`). The
`php` and `composer` commands are small wrapper scripts on your `PATH` that run
the real tool inside the matching container with your current folder mounted:

```bash
docker run --rm -v "$PWD":/app -w /app php:8.3-cli php "$@"
```

Composer is fetched once and runs with a persistent cache mounted from
`~/.composer/cache`. On Linux your user ID is mapped into the container so files
it creates are owned by you, not root.

**Compared to NVM** (for Node developers):

| | NVM | PVM |
| --- | --- | --- |
| Manages | Node.js | PHP |
| Backend | installs into `~/.nvm` | official Docker images |
| Host changes | per-version folders | none |
| Per-project file | `.nvmrc` | `.pvmrc` |
| Switch | `nvm use 18` | `pvm use 8.3` |
| Requirement | build toolchain | Docker only |

**Layout** (`~/.pvm`): `bin/` (the `pvm`, `php`, `composer` commands), `src/`
(the Bash modules), `config/` (active version), `images/` (reserved for custom
builds on the roadmap).

**Uninstall PVM completely:**

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/pvm/main/uninstall.sh | bash
# or, from a clone:  ./uninstall.sh
```

> Note: the default `php:<version>-cli` images are intentionally minimal (no
> `git`/`unzip`/extra extensions). That covers most workflows; richer toolchains
> are planned via profiles and `pvm build` (see roadmap).

## Roadmap

- **Profiles** — `pvm install 8.3 --profile laravel` (laravel, symfony,
  wordpress, magento) with the right extensions baked in.
- **Extensions** — `pvm extension install redis|xdebug|imagick`.
- **Custom images** — `pvm build` for project-specific images.

## Contributing

The code is small, modular Bash under `src/`:

- `config.sh` — paths and constants
- `utils.sh` — logging and helpers
- `docker.sh` — Docker interaction and runners
- `versions.sh` — install/use/list/resolution
- `doctor.sh` — diagnostics

Before opening a pull request:

```bash
shellcheck bin/* src/*.sh install.sh uninstall.sh   # if you have shellcheck
./tests/test_pvm.sh
```

Keep it pure Bash, strict mode (`set -euo pipefail`), and ShellCheck-clean.

## License

[MIT](LICENSE)
