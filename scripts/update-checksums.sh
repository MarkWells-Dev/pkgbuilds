#!/bin/bash
# Updates sha256sums in a PKGBUILD file
# Usage: update-checksums.sh path/to/PKGBUILD

set -e

PKGBUILD="$1"
cd "$(dirname "$PKGBUILD")"

# Source the PKGBUILD to get variables
source PKGBUILD

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
	sha=$(curl -sL "$url" | sha256sum | cut -d' ' -f1)
	sums+=("'$sha'")
done

# Update PKGBUILD
checksums=$(
	IFS=$'\n'
	echo "${sums[*]}" | tr '\n' ' ' | sed 's/ $//'
)
sed -i "s/sha256sums=.*/sha256sums=($checksums)/" PKGBUILD

echo "Updated checksums in $PKGBUILD" >&2
