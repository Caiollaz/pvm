# Releasing PVM

Releases are published automatically by GitHub Actions
(`.github/workflows/release.yml`) when a `v*` tag is pushed.

## Steps

1. Bump the version in `src/config.sh`:

   ```bash
   PVM_VERSION="0.2.0"
   ```

2. Commit it:

   ```bash
   git add src/config.sh
   git commit -m "chore: release v0.2.0"
   ```

3. Tag and push (the tag must match `v$PVM_VERSION`):

   ```bash
   git tag v0.2.0
   git push origin main --tags
   ```

The workflow validates that the tag matches `PVM_VERSION`, builds the release
assets, and publishes a GitHub Release.

## Release assets

| Asset | Purpose |
| --- | --- |
| `pvm-<version>.tar.gz` | Versioned source tarball (pinned installs) |
| `pvm.tar.gz` | Stable-named copy used by `releases/latest/download` |
| `install.sh` | The installer, fetchable per-release |
| `SHA256SUMS` | Checksums for the above (verified by the installer) |

## How users install

```bash
# latest
curl -fsSL https://github.com/Caiollaz/pvm/releases/latest/download/install.sh | bash

# pinned version
PVM_VERSION=0.2.0 curl -fsSL https://github.com/Caiollaz/pvm/releases/latest/download/install.sh | bash
```

The installer downloads the tarball and verifies it against `SHA256SUMS`
(best-effort: skipped only when no `sha256sum`/`shasum` is available).

## Verify a download manually

```bash
curl -fLO https://github.com/Caiollaz/pvm/releases/download/v0.2.0/pvm-0.2.0.tar.gz
curl -fLO https://github.com/Caiollaz/pvm/releases/download/v0.2.0/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
```

## Follow-ups (not yet implemented)

- **npm**: the bare name `pvm` is a reserved holding package; a scoped package
  (`@caiollaz/pvm`) would work. Requires making `bin/*` symlink-safe (resolve
  the real path before sourcing `src/`), since npm installs via symlink.
- **Homebrew tap**: same symlink-safe requirement.
