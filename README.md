# pkgbuilds

Personal Arch Linux package repository with automated builds and version tracking.

## Usage

```bash
# Import and trust the signing key
curl -sL https://github.com/m-wells.gpg | sudo pacman-key --add -
sudo pacman-key --lsign-key CCDA692647943A2B

# Add to /etc/pacman.conf (before [core] for priority over official packages)
[m-wells]
SigLevel = Required DatabaseOptional
Server = https://github.com/m-wells/pkgbuilds/releases/latest/download

# Sync and install
sudo pacman -Sy
sudo pacman -S gemini-cli rpi-imager
```

## Packages

| Package | Source | Description |
|---------|--------|-------------|
| gemini-cli | npm | Google's Gemini AI CLI agent |
| rpi-imager | AppImage | Raspberry Pi Imaging Utility |

## How It Works

- **PKGBUILDs** are stored in this repo
- **Renovate Bot** monitors upstream releases and creates PRs with version bumps
- **GitHub Actions** builds packages on merge to main
- **Packages are signed** with GPG and published to GitHub Releases
- **pacman** syncs directly from the release assets
