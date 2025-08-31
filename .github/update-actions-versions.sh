#!/bin/bash

# Script to update GitHub Actions to their latest patch versions
# This addresses the security warning about pinning to patch versions

echo "🔄 Updating GitHub Actions to latest patch versions..."

# Define the latest patch versions (as of August 2025)
declare -A ACTION_VERSIONS=(
    ["actions/checkout@v4"]="actions/checkout@v4.3.0"
    ["actions-rust-lang/setup-rust-toolchain@v1"]="actions-rust-lang/setup-rust-toolchain@v1.10.1"
    ["actions/setup-python@v4"]="actions/setup-python@v4.8.0"
    ["actions/setup-node@v4"]="actions/setup-node@v4.1.0"
    ["actions/cache@v3"]="actions/cache@v3.3.3"
    ["actions/github-script@v7"]="actions/github-script@v7.0.1"
)

# Update all workflow files
for file in .github/workflows/*.yml; do
    echo "📝 Updating $file..."

    for old_version in "${!ACTION_VERSIONS[@]}"; do
        new_version="${ACTION_VERSIONS[$old_version]}"
        if grep -q "$old_version" "$file"; then
            sed -i "s|$old_version|$new_version|g" "$file"
            echo "  ✅ Updated $old_version → $new_version"
        fi
    done
done

echo "✨ All GitHub Actions updated to latest patch versions!"
echo ""
echo "📋 Updated versions:"
for old_version in "${!ACTION_VERSIONS[@]}"; do
    new_version="${ACTION_VERSIONS[$old_version]}"
    echo "  • $old_version → $new_version"
done
