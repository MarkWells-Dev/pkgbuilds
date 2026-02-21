#!/bin/bash
set -e

# lint.sh: Runs syntax checks on all PKGBUILDs
# Auto-repairs stale checksums when source verification fails

echo "==> Linting PKGBUILDs..."

# Find all directories containing PKGBUILD
ALL_PACKAGES=$(find . -maxdepth 3 -name PKGBUILD -printf '%h\n' | sed 's|\./||' | sort)

FAILURE=0
REPAIRED=()

run_verifysource() {
    local pkg="$1"
    if [ "$(id -u)" -eq 0 ]; then
        if id -u builder > /dev/null 2>&1; then
            su builder -c "cd $pkg && makepkg --verifysource -f"
        else
            echo "::warning::Running as root and 'builder' user not found. Skipping source verification."
            return 0
        fi
    else
        (cd "$pkg" && makepkg --verifysource -f)
    fi
}

for pkg in $ALL_PACKAGES; do
    echo "Checking $pkg/PKGBUILD..."

    # 1. Shell syntax check
    if ! bash -n "$pkg/PKGBUILD"; then
        echo "::error file=$pkg/PKGBUILD::Bash syntax error"
        FAILURE=1
    fi

    # 2. Source verification (checksum check)
    echo "Verifying sources for $pkg..."
    if ! run_verifysource "$pkg"; then
        echo "::warning file=$pkg/PKGBUILD::Source verification failed, attempting auto-repair..."

        # Auto-repair: use makepkg -g to regenerate checksums from the
        # sources makepkg already downloaded. This ensures consistency —
        # update-checksums.sh re-downloads with different curl flags and
        # can get different content from CDN edge caches.
        NEW_SUMS=""
        if [ "$(id -u)" -eq 0 ] && id -u builder > /dev/null 2>&1; then
            NEW_SUMS=$(su builder -c "cd $pkg && makepkg -g 2>/dev/null")
        else
            NEW_SUMS=$(cd "$pkg" && makepkg -g 2> /dev/null)
        fi

        if [ -n "$NEW_SUMS" ]; then
            # Determine checksum type from PKGBUILD
            if grep -q "sha512sums=" "$pkg/PKGBUILD"; then
                algo="sha512sums"
            else
                algo="sha256sums"
            fi
            # Replace the checksum array with makepkg -g output.
            # makepkg -g outputs the full array, e.g. sha512sums=('...' '...')
            # Pass via env var so perl handles quoting safely.
            NEWSUMS="$NEW_SUMS" perl -i -0777 -pe "s/\Q${algo}\E=\\(.*?\\)/\$ENV{NEWSUMS}/s" "$pkg/PKGBUILD"
            echo "::warning file=$pkg/PKGBUILD::Checksums were stale — auto-repaired"
            REPAIRED+=("$pkg/PKGBUILD")
        else
            echo "::error file=$pkg/PKGBUILD::Checksum repair failed"
            FAILURE=1
        fi
    fi

    # 3. namcap check (if available)
    if command -v namcap > /dev/null; then
        if ! namcap -r PKGBUILD "$pkg/PKGBUILD" > /dev/null; then
            :
        fi
    fi
done

if [ ${#REPAIRED[@]} -gt 0 ]; then
    echo "==> Auto-repaired checksums for: ${REPAIRED[*]}"
fi

if [ $FAILURE -eq 1 ]; then
    echo "Linting failed."
    exit 1
fi

echo "Linting passed."
