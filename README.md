# pkgbuilds

[![Build packages](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/build.yml/badge.svg)](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/build.yml)
[![Check for Updates](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/watch.yml/badge.svg)](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/watch.yml)

Personal Arch Linux package repository with automated builds and version tracking.

## Usage

```bash
# Import the maintainer's signing key
sudo pacman-key --keyserver keys.openpgp.org --recv-keys ED9FEE0BB96D6A5E
sudo pacman-key --lsign-key ED9FEE0BB96D6A5E

# Add to /etc/pacman.conf (before [core] for priority over official packages)
[mark-wells-dev]
SigLevel = Required DatabaseOptional
Server = https://github.com/mark-wells-dev/pkgbuilds/releases/latest/download

# Sync and install
sudo pacman -Sy
sudo pacman -S <package-name>
```

## Packages

| Package                    | Source   | Description                   |
| -------------------------- | -------- | ----------------------------- |
| gemini-cli                 | npm      | Google's Gemini AI CLI agent  |
| keeper-commander           | PyPI     | Keeper Password Manager CLI   |
| keeper-secrets-manager-cli | PyPI     | Keeper Secrets Manager CLI    |
| rpi-imager                 | AppImage | Raspberry Pi Imaging Utility  |
| virtctl                    | Binary   | Kubernetes Virtualization CLI |

## How It Works

- **PKGBUILDs** are stored in this repo
- **CI/CD** via GitHub Actions (builds in clean Arch Linux container)
- **Automatic Releases** created when changes are pushed to `main`
- **GitHub Actions** builds packages on merge to main (only changed packages are rebuilt)
- **Packages are signed** with GPG and published to GitHub Releases
- **pacman** syncs directly from the release assets

### CI Details

- Only changed packages are rebuilt (detected via GitHub API)
- Deleted packages are automatically removed from the repo database
- Old package versions are cleaned up when new versions are uploaded
- If a build fails, remaining packages continue building; successful packages are still released
- **Force rebuild all**: Use Actions → "Run workflow" → check "Rebuild all packages"

## Adding a New Package

1. Create a directory in `pkgs/` with a `PKGBUILD` (directory name must match `pkgname`):

   ```
   pkgs/my-package/
   └── PKGBUILD    # pkgname=my-package
   ```

2. Add an update script in `scripts/packages/<pkgname>.sh`:

```bash
check_pkgname() {

  # check logic here, call perform_update

}

check_pkgname
```

Common datasources:

- `npm` - for npm packages
- `github-releases` - for GitHub releases

3. Commit and push - the package will be automatically detected and built

## Known Issues

### rpi-imager URL opening

Clicking links within the `rpi-imager` application may fail. This occurs because the AppImage's bundled libraries can break PAM when calling `runuser` to launch a browser. This is an upstream issue; avoid attempting downstream fixes in the wrapper script as they have proven unreliable.

## Contributing

For detailed instructions on how to add new packages, build them locally, and understand the project structure, please see [CONTRIBUTING.md](./CONTRIBUTING.md).
