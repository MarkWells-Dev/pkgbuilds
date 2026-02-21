#!/bin/bash
set -e

# release.sh: Atomic release publishing
# Creates a fresh GitHub release with all assets, then marks it as latest.
# Uses a draft release during upload to ensure atomicity — the old release
# stays live until the new one is fully uploaded and published.

# Source common variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

KEEP_RELEASES=3
STAGING_DIR="release-staging"
NEW_TAG="release-$(date -u +%Y%m%d-%H%M%S)"

echo "==> Starting atomic release (tag: $NEW_TAG)..."

# 1. Download all current assets from the latest release
mkdir -p "$STAGING_DIR"
echo "==> Downloading current release assets..."
if ! gh release download --dir "$STAGING_DIR" --pattern '*' --skip-existing 2> /dev/null; then
    echo "No existing release found — this will be the first."
fi

# 2. Remove packages that were deleted from the repo
if [ -n "$REMOVED_JSON" ] && [ "$REMOVED_JSON" != "[]" ]; then
    echo "==> Removing deleted packages from staging..."
    for pkg_name in $(echo "$REMOVED_JSON" | jq -r '.[]'); do
        echo "Removing $pkg_name..."
        rm -f "${STAGING_DIR}/${pkg_name}"-*.pkg.tar.zst "${STAGING_DIR}/${pkg_name}"-*.pkg.tar.zst.sig
    done
fi

# 3. Overlay newly built packages, DB files, and signatures from repo/
if [ -d repo ] && [ "$(ls -A repo/ 2> /dev/null)" ]; then
    echo "==> Overlaying new artifacts from repo/..."
    cp -f repo/*.pkg.tar.zst "$STAGING_DIR/" 2> /dev/null || true
    cp -f repo/*.sig "$STAGING_DIR/" 2> /dev/null || true
    cp -f repo/*.db.tar.gz "$STAGING_DIR/" 2> /dev/null || true
    cp -f repo/*.files.tar.gz "$STAGING_DIR/" 2> /dev/null || true
    cp -f repo/*.db "$STAGING_DIR/" 2> /dev/null || true
    cp -f repo/*.files "$STAGING_DIR/" 2> /dev/null || true
    cp -f repo/*.db.sig "$STAGING_DIR/" 2> /dev/null || true
    cp -f repo/*.files.sig "$STAGING_DIR/" 2> /dev/null || true
fi

# Verify we have something to upload
ASSET_COUNT=$(find "$STAGING_DIR" -maxdepth 1 -type f | wc -l)
if [ "$ASSET_COUNT" -eq 0 ]; then
    echo "::error::No assets to upload. Aborting release."
    exit 1
fi
echo "==> $ASSET_COUNT assets ready for upload."

# 4. Create a draft release on the new tag
echo "==> Creating draft release on tag $NEW_TAG..."
git tag "$NEW_TAG"
git push origin "$NEW_TAG"

# Collect asset files
ASSET_FILES=()
for f in "$STAGING_DIR"/*; do
    [ -f "$f" ] && ASSET_FILES+=("$f")
done

gh release create "$NEW_TAG" \
    --draft \
    --title "Packages" \
    --notes "Arch Linux binary packages (built $(date -u +%Y-%m-%d))" \
    "${ASSET_FILES[@]}"

# 5. Publish the draft and mark as latest
echo "==> Publishing release and marking as latest..."
gh release edit "$NEW_TAG" --draft=false --latest

echo "==> Release $NEW_TAG is now live."

# 6. Clean up old releases (keep the last $KEEP_RELEASES non-draft releases)
echo "==> Cleaning up old releases (keeping last $KEEP_RELEASES)..."
OLD_TAGS=$(gh release list --limit 50 --json tagName,isDraft \
    --jq "[.[] | select(.isDraft == false)] | sort_by(.tagName) | reverse | .[${KEEP_RELEASES}:] | .[].tagName")

for old_tag in $OLD_TAGS; do
    echo "Deleting old release: $old_tag"
    gh release delete "$old_tag" --yes --cleanup-tag 2> /dev/null || true
done

echo "==> Atomic release complete."
