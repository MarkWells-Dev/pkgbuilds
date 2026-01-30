#!/bin/bash
set -e
PKG_FILE="$1"

echo "Testing virtctl..."
if [ -z "$PKG_FILE" ]; then
    echo "Error: Package file not provided"
    exit 1
fi

# Install the package
sudo pacman -U --noconfirm "$PKG_FILE"

# Run version check
/usr/bin/virtctl version --client
