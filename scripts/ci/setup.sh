#!/bin/bash
set -e

# setup.sh: Prepares the Arch Linux environment for CI jobs.

echo "==> Setting up build environment..."

# 1. Update system and install base dependencies
# We check if we are in an Arch environment first
if [ ! -f /etc/arch-release ]; then
    echo "Error: This script must be run on Arch Linux."
    exit 1
fi

# Ensure base-devel is present (though the container should have it)
pacman -Syu --noconfirm
pacman -S --noconfirm --needed npm fuse2 zlib github-cli sudo git base-devel jq

# 2. Setup non-root builder user
if ! id -u builder > /dev/null 2>&1; then
    echo "==> Creating builder user..."
    useradd -m builder
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# 3. Fix permissions for the workspace
# GitHub Actions checkouts are owned by root in containers
chown -R builder:builder .
# Allow builder to access the GITHUB_OUTPUT file (owned by root usually)
if [ -n "$GITHUB_OUTPUT" ]; then
    chmod 666 "$GITHUB_OUTPUT"
fi

echo "==> Setup complete."
