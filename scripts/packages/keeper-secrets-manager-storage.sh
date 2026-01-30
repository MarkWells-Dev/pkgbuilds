#!/bin/bash

check_keeper_secrets_manager_storage() {
    local pkg_name="keeper-secrets-manager-storage"
    local pypi_name="keeper-secrets-manager-storage"
    echo "Checking $pkg_name via PyPI..."

    local latest_ver=$(curl -s "https://pypi.org/pypi/${pypi_name}/json" | jq -r .info.version)

    if [ -n "$latest_ver" ] && [ "$latest_ver" != "null" ]; then
        perform_update "$pkg_name" "$latest_ver"
    else
        echo "Failed to check version for $pkg_name"
    fi
}

check_keeper_secrets_manager_storage
