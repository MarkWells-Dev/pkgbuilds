#!/bin/bash
# Updates checksums in a PKGBUILD file (supports sha256sums and sha512sums)
# Usage: update-checksums.sh path/to/PKGBUILD

set -e

PKGBUILD_PATH="$1"
PKGBUILD_DIR="$(dirname "$PKGBUILD_PATH")"
PKGBUILD_FILE="$(basename "$PKGBUILD_PATH")"

# Ensure we are in the correct directory for local file sources
cd "$PKGBUILD_DIR"

# Source the PKGBUILD to get variables
# shellcheck source=/dev/null
source "$PKGBUILD_FILE"

# Determine checksum type
if grep -q "sha512sums=" "$PKGBUILD_FILE"; then
    algo="sha512"
    sum_cmd="sha512sum"
else
    algo="sha256"
    sum_cmd="sha256sum"
fi

echo "Updating $algo checksums for $PKGBUILD_PATH..."

# Calculate checksums for each source
sums=()
# shellcheck disable=SC2154
for src in "${source[@]}"; do
    # Handle source with custom filename (filename::url)
    if [[ "$src" == *::* ]]; then
        url="${src#*::}"
    else
        url="$src"
    fi

    # Expand variables in URL
    url=$(eval echo "$url")

    echo "Fetching: $url" >&2
    if [[ "$url" == http* ]]; then
        # Use a temporary file to ensure we don't hash error pages
        tmp_file=$(mktemp)
        if ! curl -sLf "$url" -o "$tmp_file"; then
            echo "Error: Failed to download $url" >&2
            rm -f "$tmp_file"
            exit 1
        fi
        sha=$($sum_cmd "$tmp_file" | cut -d' ' -f1)
        rm -f "$tmp_file"
    else
        # Local file
        if [ -f "$url" ]; then
            sha=$($sum_cmd "$url" | cut -d' ' -f1)
        else
            echo "Error: Local file $url not found" >&2
            exit 1
        fi
    fi
    sums+=("'$sha'")
done

# Update PKGBUILD
checksums=$(
    IFS=$'\n'
    echo "${sums[*]}" | tr '\n' ' ' | sed 's/ $//'
)

# Replace the existing checksum array (handles multi-line)
# We use perl in slurp mode to handle multi-line checksum arrays
perl -i -0777 -pe "s/${algo}sums=\\\(.*?\\\)/${algo}sums=($checksums)/sg" "$PKGBUILD_FILE"

echo "Updated $algo checksums in $PKGBUILD_PATH" >&2
