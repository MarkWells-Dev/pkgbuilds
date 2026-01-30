#!/bin/bash
set -e
PKG_FILE="$1"

echo "Testing rpi-imager..."
if [ -z "$PKG_FILE" ]; then
    echo "Error: Package file not provided"
    exit 1
fi

# Install the package
sudo pacman -U --noconfirm "$PKG_FILE"

# Verify binary exists and is executable
if [ -x /usr/bin/rpi-imager ]; then
    echo "Binary /usr/bin/rpi-imager exists and is executable."
else
    echo "Error: Binary not found or not executable."
    exit 1
fi

# Also check the /opt location for the AppImage
if [ -x /opt/rpi-imager/rpi-imager.AppImage ]; then
    echo "AppImage installed correctly."
else
    echo "Error: AppImage not found in /opt."
    exit 1
fi
