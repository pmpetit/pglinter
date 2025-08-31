#!/bin/bash
# Script to validate GitHub Actions workflows locally
# This helps catch issues before pushing to GitHub

set -e

echo "🔍 Validating GitHub Actions workflows..."

# Check if act is installed (for local testing)
if command -v act &> /dev/null; then
    echo "✅ act is available for local testing"
    ACT_AVAILABLE=true
else
    echo "ℹ️  act not available (install with 'brew install act' or 'sudo snap install act')"
    ACT_AVAILABLE=false
fi

# Validate YAML syntax
echo ""
echo "📋 Checking YAML syntax..."
for workflow in .github/workflows/*.yml; do
    if [ -f "$workflow" ]; then
        echo "  Checking $workflow..."
        if command -v yamllint &> /dev/null; then
            yamllint "$workflow"
        elif python3 -c "import yaml" 2>/dev/null; then
            python3 -c "
import yaml
import sys
try:
    with open('$workflow', 'r') as f:
        yaml.safe_load(f)
    print('  ✅ Valid YAML')
except Exception as e:
    print(f'  ❌ Invalid YAML: {e}')
    sys.exit(1)
"
        else
            echo "  ⚠️  No YAML validator available (install yamllint or ensure python3 has PyYAML)"
        fi
    fi
done

# Check for common issues
echo ""
echo "🔍 Checking for common workflow issues..."

# Check for action versions
echo "  📦 Checking action versions..."
grep -r "uses:" .github/workflows/ | while read -r line; do
    if echo "$line" | grep -q "@v[0-9]$"; then
        echo "  ⚠️  Consider pinning to patch version: $line"
    fi
done

# Check for secrets usage
echo "  🔐 Checking secrets usage..."
if grep -r "secrets\." .github/workflows/ > /dev/null; then
    echo "  ℹ️  Found secrets usage - ensure they're properly configured in repo settings"
fi

# Test pre-commit locally
echo ""
echo "🧪 Testing pre-commit configuration..."
if command -v pre-commit &> /dev/null; then
    echo "  Running pre-commit on sample files..."
    # Just validate the config
    pre-commit run --all-files --verbose || {
        echo "  ⚠️  Pre-commit found issues - this will cause CI to fail"
        echo "  💡 Run 'make precommit-fast' to fix issues"
    }
else
    echo "  ⚠️  pre-commit not installed - install with 'pip install pre-commit'"
fi

# Test local Makefile targets
echo ""
echo "🔨 Testing Makefile targets used in workflows..."
if make --dry-run precommit-fast > /dev/null 2>&1; then
    echo "  ✅ make precommit-fast target exists"
else
    echo "  ❌ make precommit-fast target missing or broken"
fi

if make --dry-run lint-docs > /dev/null 2>&1; then
    echo "  ✅ make lint-docs target exists"
else
    echo "  ❌ make lint-docs target missing or broken"
fi

# Suggest local testing with act
if [ "$ACT_AVAILABLE" = true ]; then
    echo ""
    echo "🎭 You can test workflows locally with act:"
    echo "  # Test the required checks workflow"
    echo "  act pull_request -W .github/workflows/required-checks.yml"
    echo ""
    echo "  # Test the PR guard workflow"
    echo "  act pull_request -W .github/workflows/pr-precommit-guard.yml"
fi

echo ""
echo "✅ Workflow validation complete!"
echo ""
echo "💡 Next steps:"
echo "  1. Commit and push these workflow files"
echo "  2. Set up branch protection rules in GitHub repository settings"
echo "  3. Test with a pull request to main branch"
