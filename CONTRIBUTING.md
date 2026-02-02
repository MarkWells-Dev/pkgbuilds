# Contributing to pkgbuilds

This guide provides instructions for building, testing, and adding packages to this repository.

For detailed documentation, see the [Wiki](https://github.com/MarkWells-Dev/pkgbuilds/wiki):

- [Build Patterns](https://github.com/MarkWells-Dev/pkgbuilds/wiki/Build-Patterns) - npm, Python, AppImage, and binary packaging
- [CI/CD Workflow](https://github.com/MarkWells-Dev/pkgbuilds/wiki/CI-CD) - Pipeline, dependency resolution, and deployment

## Development Environment

These instructions assume you are using Arch Linux.

### Building Packages Locally

```bash
cd pkgs/[package-name]
makepkg -s
```

Common flags:

- `-s`: Install missing dependencies automatically
- `-f`: Force rebuild (overwrite existing package)

### Updating Checksums

If you change source URLs or manually bump versions:

```bash
updpkgsums
```

## Repository Structure

```text
pkgs/
├── gemini-cli/
│   ├── PKGBUILD
│   ├── .local           # ← build + publish to GitHub releases
│   └── check.sh
├── keeper-secrets-manager-helper/
│   ├── PKGBUILD
│   └── .aur             # ← push to AUR only
└── some-package/
    ├── PKGBUILD
    ├── .local           # ← can have both markers
    ├── .aur
    └── check.sh
```

### Target Markers

| Marker   | Behavior                             |
| -------- | ------------------------------------ |
| `.local` | Build and publish to GitHub releases |
| `.aur`   | Push PKGBUILD to AUR                 |

## Adding a New Package

1. Create directory in `pkgs/` (name must match `pkgname`)
2. Add `PKGBUILD` following appropriate [build pattern](./docs/build-patterns.md)
3. Add target marker (`.local`, `.aur`, or both)
4. Add `check.sh` smoke test (for `.local` packages)
5. Add version check script in `scripts/packages/[pkgname].sh`

## Automated Updates

Version checks run via GitHub Actions. Add a script in `scripts/packages/`:

```bash
# scripts/packages/example.sh
check_example() {
  local latest=$(curl -s "https://api.example.com/version")
  perform_update "example" "$latest"
}
check_example
```

Common version sources:

- **npm**: `npm view @scope/package version`
- **PyPI**: `curl -s https://pypi.org/pypi/package/json | jq -r .info.version`
- **GitHub**: `curl -s https://api.github.com/repos/org/repo/releases/latest | jq -r .tag_name`
