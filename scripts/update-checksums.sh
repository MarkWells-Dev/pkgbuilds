#!/bin/bash
# Updates checksums in a PKGBUILD file (supports sha256sums and sha512sums)
# Usage: update-checksums.sh path/to/PKGBUILD

set -e

PKGBUILD="$1"
cd "$(dirname "$PKGBUILD")"

# Source the PKGBUILD to get variables
source PKGBUILD

# Determine checksum type
if grep -q "sha512sums=" PKGBUILD; then
    algo="sha512"
    sum_cmd="sha512sum"
else
    algo="sha256"
    sum_cmd="sha256sum"
fi

echo "Updating $algo checksums for $PKGBUILD..."

# Calculate checksums for each source
sums=()
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
    sha=$(curl -sL "$url" | $sum_cmd | cut -d' ' -f1)
    sums+=("'$sha'")
done

# Update PKGBUILD
checksums=$(
    IFS=$'\n'
    echo "${sums[*]}" | tr '\n' ' ' | sed 's/ $//'
)

# Replace the existing checksum array (handles multi-line)
perl -i -0777 -pe "s/${algo}sums=\(.*?\)/${algo}sums=($checksums)/sg" "$PKGBUILD"

echo "Updated $algo checksums in $PKGBUILD" >&2
