#!/bin/bash

# Fix duplicated action versions caused by sed replacing multiple times

echo "🔧 Fixing duplicated action versions..."

# Define the correct versions
declare -A CORRECT_VERSIONS=(
    ["actions/checkout@v4.3.0.3.0"]="actions/checkout@v4.3.0"
    ["actions-rust-lang/setup-rust-toolchain@v1.10.1.10.1"]="actions-rust-lang/setup-rust-toolchain@v1.10.1"
    ["actions/setup-python@v4.8.0.8.0"]="actions/setup-python@v4.8.0"
    ["actions/setup-node@v4.1.0.1.0"]="actions/setup-node@v4.1.0"
    ["actions/cache@v3.3.3.3.3"]="actions/cache@v3.3.3"
    ["actions/github-script@v7.0.1.0.1"]="actions/github-script@v7.0.1"
)

# Fix all workflow files
for file in .github/workflows/*.yml; do
    echo "📝 Fixing $file..."

    for wrong_version in "${!CORRECT_VERSIONS[@]}"; do
        correct_version="${CORRECT_VERSIONS[$wrong_version]}"
        if grep -q "$wrong_version" "$file"; then
            sed -i "s|$wrong_version|$correct_version|g" "$file"
            echo "  ✅ Fixed $wrong_version → $correct_version"
        fi
    done
done

echo "✨ All duplicated versions fixed!"
