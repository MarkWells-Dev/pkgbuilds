#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
PACKAGES_DIR="$SCRIPT_DIR/packages"

# Source common logic
source "$LIB_DIR/common.sh"

# Run all package check scripts
for script in "$PACKAGES_DIR"/*.sh; do
    if [ -f "$script" ]; then
        echo "::group::Checking $(basename "$script")"
        # Run in subshell so a failure doesn't stop the master script
        # shellcheck source=/dev/null
        if ! (source "$script"); then
            echo "::error::Failed to check updates for $(basename "$script")"
        fi
        echo "::endgroup::"
    fi
done
