# Contributing to PVM

Thanks for helping improve PVM! Contributions of all sizes are welcome —
bug reports, docs, and code.

## Ground rules

- **Pure Bash.** No other runtime dependencies. Docker is the only thing PVM
  relies on at runtime.
- **Strict mode.** Every script starts with `set -euo pipefail`.
- **ShellCheck-clean.** Lint before you push.
- **Keep it simple.** PVM's value is being small and obvious.

## Project layout

```text
bin/        pvm, php, composer        # entry points / wrappers
src/        config, utils, docker,    # modular Bash sources
            versions, doctor
tests/      pure-bash test suite
docs/       command reference
install.sh  / uninstall.sh            # installer / uninstaller
```

- `config.sh` — paths and constants
- `utils.sh` — logging and small helpers
- `docker.sh` — all Docker interaction and the `php`/`composer` runners
- `versions.sh` — install/uninstall/list/available/use/current + resolution
- `doctor.sh` — diagnostics

## Local checks

Run both before opening a pull request:

```bash
shellcheck -s bash bin/pvm bin/php bin/composer src/*.sh install.sh uninstall.sh tests/*.sh
./tests/test_pvm.sh
```

Don't have ShellCheck? `sudo apt install shellcheck` (Linux) or
`brew install shellcheck` (macOS). At minimum, syntax-check everything:

```bash
for f in bin/pvm bin/php bin/composer src/*.sh install.sh uninstall.sh tests/*.sh; do bash -n "$f"; done
```

CI runs ShellCheck, the unit tests, and an end-to-end matrix (PHP 8.1–8.4 via
Docker) on every push and pull request.

## Pull requests

1. Fork and create a branch (`feat/...`, `fix/...`).
2. Make the change; add or update tests where it makes sense.
3. Run the local checks above.
4. Open the PR with a clear description of *what* and *why*.

## Reporting bugs

Open an issue with:

- your OS and `docker --version`
- the exact command you ran
- the output of `pvm doctor`
- what you expected vs. what happened

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
