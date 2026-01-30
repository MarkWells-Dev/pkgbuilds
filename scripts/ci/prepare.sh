#!/bin/bash
set -e

# prepare.sh: Determines which packages need building.
# Outputs: 'matrix', 'removed', 'run_publish', 'has_work' to $GITHUB_OUTPUT

echo "==> Preparing build matrix..."

# Ensure we have the builder user (setup.sh should have run)
if ! id -u builder > /dev/null 2>&1; then
    echo "Error: builder user not found. Run setup.sh first."
    exit 1
fi

mkdir -p repo

# 1. Download Repository Database
echo "==> Downloading repository database..."

if ! gh release download latest --repo "$GITHUB_REPOSITORY" --pattern 'mark-wells-dev.db.tar.gz' --dir repo 2> /dev/null; then
    echo "No existing database found. Starting fresh."
else
    # Also try to get the files db
    gh release download latest --repo "$GITHUB_REPOSITORY" --pattern 'mark-wells-dev.files.tar.gz' --dir repo 2> /dev/null || true
fi

# Extract DB to read versions
mkdir -p repo/db_content
if [ -f repo/mark-wells-dev.db.tar.gz ]; then
    tar -xf repo/mark-wells-dev.db.tar.gz -C repo/db_content
fi

# 2. Map Current DB Versions
touch db_versions.txt
find repo/db_content -name desc | while read -r desc_file; do
    name=$(grep -A1 "%NAME%" "$desc_file" | tail -n1)
    ver=$(grep -A1 "%VERSION%" "$desc_file" | tail -n1)
    echo "$name $ver" >> db_versions.txt
done
echo "Current DB versions:"
cat db_versions.txt

# Clean up extracted content to avoid artifact upload issues (colons in filenames)
rm -rf repo/db_content

# 3. Scan Local Packages
# Find directories containing PKGBUILD
ALL_PACKAGES=$(find . -maxdepth 3 -name PKGBUILD -printf '%h\n' | sed 's|^\./||' | sort | tr '\n' ' ' | xargs)
echo "Local packages: $ALL_PACKAGES"

PACKAGES_TO_BUILD=()
REMOVED_PACKAGES=()

# Check for forced rebuild
if [ "$FORCE_REBUILD" = "true" ]; then
    echo "Force rebuild active: building all packages."
    for pkg in $ALL_PACKAGES; do
        PACKAGES_TO_BUILD+=("$pkg")
    done
else
    # Standard change detection
    for pkg in $ALL_PACKAGES; do
        echo "Checking $pkg..."

        # Parse PKGBUILD using makepkg (as builder)
        echo "Parsing PKGBUILD for $pkg..."
        if ! srcinfo=$(su builder -c "cd $pkg && makepkg --printsrcinfo" 2>&1); then
            echo "::error::Failed to parse PKGBUILD for $pkg. Error output:"
            echo "$srcinfo"
            exit 1
        fi

        p_name=$(echo "$srcinfo" | grep -P '^\t?pkgname =' | cut -d= -f2 | xargs)
        p_ver=$(echo "$srcinfo" | grep -P '^\t?pkgver =' | cut -d= -f2 | xargs)
        p_rel=$(echo "$srcinfo" | grep -P '^\t?pkgrel =' | cut -d= -f2 | xargs)
        p_epoch=$(echo "$srcinfo" | grep -P '^\t?epoch =' | cut -d= -f2 | xargs)

        if [ -n "$p_epoch" ]; then
            local_ver="${p_epoch}:${p_ver}-${p_rel}"
        else
            local_ver="${p_ver}-${p_rel}"
        fi

        # Find version in DB using actual package name (not directory path)
        db_ver=$(grep "^$p_name " db_versions.txt | cut -d' ' -f2 || echo "")

        if [ -z "$db_ver" ]; then
            echo "New package: $pkg ($local_ver)"
            PACKAGES_TO_BUILD+=("$pkg")
        else
            # Compare versions
            cmp_res=$(vercmp "$local_ver" "$db_ver")
            if [ "$cmp_res" -ne 0 ]; then
                echo "Update needed for $pkg: DB($db_ver) -> Local($local_ver)"
                PACKAGES_TO_BUILD+=("$pkg")
            else
                echo "$pkg is up to date ($local_ver)"
            fi
        fi
    done
fi

# 4. Detect Removed Packages
while read -r line; do
    [ -z "$line" ] && continue
    db_name=$(echo "$line" | cut -d' ' -f1)
    # Check if db_name exists in ALL_PACKAGES (compare using basename since paths are now pkgs/name)
    found=false
    for pkg in $ALL_PACKAGES; do
        pkg_basename=$(basename "$pkg")
        if [ "$pkg_basename" = "$db_name" ]; then
            found=true
            break
        fi
    done
    if [ "$found" = "false" ]; then
        echo "Package $db_name is in DB but not local (will be removed)."
        REMOVED_PACKAGES+=("$db_name")
    fi
done < db_versions.txt

# 5. Output Results to GitHub Actions
# Convert arrays to JSON safely
if [ ${#PACKAGES_TO_BUILD[@]} -eq 0 ]; then
    matrix_json="[]"
else
    matrix_json=$(printf '%s\n' "${PACKAGES_TO_BUILD[@]}" | jq -R . | jq -s -c .)
fi

if [ ${#REMOVED_PACKAGES[@]} -eq 0 ]; then
    removed_json="[]"
else
    removed_json=$(printf '%s\n' "${REMOVED_PACKAGES[@]}" | jq -R . | jq -s -c .)
fi

# Use heredoc for multi-line values in GITHUB_OUTPUT
{
    echo "matrix<<EOF"
    echo "$matrix_json"
    echo "EOF"
    echo "removed<<EOF"
    echo "$removed_json"
    echo "EOF"
} >> "$GITHUB_OUTPUT"

# Determine flags
if [ ${#PACKAGES_TO_BUILD[@]} -gt 0 ] || [ ${#REMOVED_PACKAGES[@]} -gt 0 ]; then
    echo "has_work=true" >> "$GITHUB_OUTPUT"
    echo "run_publish=true" >> "$GITHUB_OUTPUT"
else
    echo "has_work=false" >> "$GITHUB_OUTPUT"
    # If FIX_SIGNATURES is set, we still need to run publish
    if [ "$FIX_SIGNATURES" = "true" ]; then
        echo "run_publish=true" >> "$GITHUB_OUTPUT"
        echo "Fix signatures requested."
    else
        echo "run_publish=false" >> "$GITHUB_OUTPUT"
    fi
fi

echo "Preparation complete."
echo "Matrix: $matrix_json"
echo "Removed: $removed_json"
