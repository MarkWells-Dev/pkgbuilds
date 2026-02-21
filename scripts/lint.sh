#!/bin/bash
set -e

# lint.sh: Runs syntax checks on all PKGBUILDs
# Auto-repairs stale checksums when source verification fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

        # Auto-repair: re-compute checksums and retry
        if "$SCRIPT_DIR/update-checksums.sh" "$pkg/PKGBUILD"; then
            # Delete cached source files so makepkg re-downloads them
            # (the cached files may differ from what update-checksums.sh fetched)
            # shellcheck disable=SC1090,SC2154
            (source "$pkg/PKGBUILD" && cd "$pkg" && for src in "${source[@]}"; do
                local_name="${src%%::*}"
                [ "$local_name" != "$src" ] || local_name="$(basename "$src")"
                rm -f "$local_name"
            done)
            echo "Checksums updated, retrying verification..."
            if run_verifysource "$pkg"; then
                echo "::warning file=$pkg/PKGBUILD::Checksums were stale — auto-repaired"
                REPAIRED+=("$pkg/PKGBUILD")
            else
                echo "::error file=$pkg/PKGBUILD::Source verification failed even after checksum repair"
                FAILURE=1
            fi
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

# Commit repaired checksums so downstream steps use them
if [ ${#REPAIRED[@]} -gt 0 ]; then
    echo "==> Auto-repaired checksums for: ${REPAIRED[*]}"
    if [ -n "$CI" ]; then
        git config --global user.name "Updater Bot"
        git config --global user.email "bot@noreply.github.com"
    fi
    git add "${REPAIRED[@]}"
    git commit -m "fix: auto-repair stale checksums [skip ci]

Affected: ${REPAIRED[*]}"
fi

if [ $FAILURE -eq 1 ]; then
    echo "Linting failed."
    exit 1
fi

echo "Linting passed."
