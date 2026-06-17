## What

Briefly describe the change.

## Why

What problem does it solve?

## Checklist

- [ ] `shellcheck -s bash bin/pvm bin/php bin/composer src/*.sh install.sh uninstall.sh tests/*.sh` passes
- [ ] `./tests/test_pvm.sh` passes
- [ ] Pure Bash, strict mode, no new runtime dependencies
- [ ] Docs updated if behavior changed
