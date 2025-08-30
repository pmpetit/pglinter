#!/bin/bash
# Pre-commit hook for pglinter
#
# To install this hook:
#   cp pre-commit-hook.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# To run manually:
#   make precommit

set -e

echo "🔍 Running pglinter pre-commit checks..."

# Run the precommit target
make precommit-fast

echo ""
echo "🎉 Pre-commit checks passed! Committing..."
