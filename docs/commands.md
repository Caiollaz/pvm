# pvm command reference

All commands are `pvm <command> [args]`. Docker must be installed and running.
`curl`/`wget` install PVM only; they do not install Docker. On Windows, install
Docker Desktop from an Administrator PowerShell with:

```powershell
choco install docker-desktop -y
```

| Command | Description | Internally |
| --- | --- | --- |
| `pvm install [<version>]` | Make a PHP version available; no arg reads project files | `docker pull php:<version>-cli` (skipped if cached) |
| `pvm uninstall <version>` | Remove a PHP version | `docker image rm php:<version>-cli` |
| `pvm list` | List installed versions (`*` = active) | reads local Docker images |
| `pvm available` | List versions you can install | static list (8.1–8.4) |
| `pvm use [<version>]` | Set the active global version; no arg reads project files | writes `~/.pvm/config/version` |
| `pvm current` | Print the active version | resolution order below |
| `pvm doctor` | Diagnose Docker, PATH, config, active version | — |
| `pvm language [pt\|en]` | Show or set terminal message language | writes `~/.pvm/config/lang` |
| `pvm version` | pvm's own version | — |
| `pvm help` | Usage | — |

## Wrappers

Installed onto your `PATH` at `~/.pvm/bin`:

- `php` — runs `php` inside the active version's container (`php artisan ...`, `phpunit`, `pest`, …).
- `composer` — runs Composer inside the active container with a persistent cache mounted from `~/.composer/cache`.

## Active version resolution

1. `$PVM_PHP_VERSION` environment variable
2. nearest project version file (searching up from the current directory)
3. global version in `~/.pvm/config/version`

Inside a directory, project files are checked in this order:

1. `.pvmrc`
2. `.php-version`
3. `composer.json` `require.php`

## Per-project version

```bash
echo "8.2" > .pvmrc
php -v        # uses 8.2 inside this tree
```

You can also use `.php-version`, or the normal Composer requirement:

```json
{
  "require": {
    "php": "^8.2"
  }
}
```

## Terminal language

```bash
pvm language pt
pvm language en
PVM_LANG=en pvm doctor
```

## Notes

- Default images are the official `php:<version>-cli`. They are minimal (no
  `git`/`unzip`/`zip` extension). Composer works for most workflows via its
  internal downloader; richer toolchains arrive with profiles and `pvm build`
  on the roadmap.
- On Linux your UID/GID are mapped into the container so files created by
  `php`/`composer` are owned by you, not root.
