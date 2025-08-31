#!/bin/bash
# Setup script for GitHub Actions pre-commit workflows
# This script helps set up the development environment and validates the workflows

set -e

echo "🚀 Setting up pglinter GitHub Actions pre-commit workflows..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "Cargo.toml" ]] || [[ ! -f "Makefile" ]]; then
    print_error "Please run this script from the pglinter project root directory"
    exit 1
fi

print_step "Checking prerequisites..."

# Check for required tools
MISSING_TOOLS=()

if ! command -v cargo &> /dev/null; then
    MISSING_TOOLS+=("cargo (Rust)")
fi

if ! command -v python3 &> /dev/null; then
    MISSING_TOOLS+=("python3")
fi

if ! command -v node &> /dev/null; then
    MISSING_TOOLS+=("node.js")
fi

if ! command -v npm &> /dev/null; then
    MISSING_TOOLS+=("npm")
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    print_error "Missing required tools: ${MISSING_TOOLS[*]}"
    echo "Please install the missing tools and run this script again."
    exit 1
fi

print_success "All required tools are available"

# Install pre-commit
print_step "Installing pre-commit..."
if ! command -v pre-commit &> /dev/null; then
    pip3 install --user pre-commit
    print_success "Installed pre-commit"
else
    print_success "pre-commit already installed"
fi

# Install codespell
print_step "Installing codespell..."
if ! command -v codespell &> /dev/null; then
    pip3 install --user codespell
    print_success "Installed codespell"
else
    print_success "codespell already installed"
fi

# Install markdownlint
print_step "Installing markdownlint..."
if ! command -v markdownlint &> /dev/null; then
    npm install -g markdownlint-cli
    print_success "Installed markdownlint"
else
    print_success "markdownlint already installed"
fi

# Set up pre-commit hooks
print_step "Setting up pre-commit hooks..."
pre-commit install
print_success "Pre-commit hooks installed"

# Install the git pre-commit hook
print_step "Installing git pre-commit hook..."
make install-precommit-hook
print_success "Git pre-commit hook installed"

# Validate workflows
print_step "Validating GitHub Actions workflows..."
./.github/workflows/validate.sh

# Test pre-commit functionality
print_step "Testing pre-commit functionality..."
echo "Running fast pre-commit checks..."

if make precommit-fast; then
    print_success "Pre-commit checks passed!"
else
    print_warning "Pre-commit checks found issues. You may want to fix them before committing."
    echo ""
    echo "💡 Common fixes:"
    echo "  - Run 'cargo fmt' to fix formatting"
    echo "  - Run 'cargo clippy --fix --allow-dirty' to fix linting issues"
    echo "  - Run 'make lint-docs-fix' to fix documentation issues"
fi

# Show status
echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 What was set up:"
echo "  ✅ GitHub Actions workflows in .github/workflows/"
echo "  ✅ Pre-commit hooks installed"
echo "  ✅ Git pre-commit hook installed"
echo "  ✅ Required tools validated"
echo ""
echo "🔧 Available commands:"
echo "  make precommit-fast   - Run fast pre-commit checks"
echo "  make precommit        - Run full pre-commit checks with tests"
echo "  make lint-docs-fix    - Fix documentation formatting issues"
echo "  pre-commit run --all-files - Run pre-commit hooks manually"
echo ""
echo "🚀 Next steps:"
echo "  1. Commit these workflow files:"
echo "     git add .github/"
echo "     git commit -m 'Add GitHub Actions pre-commit workflows'"
echo ""
echo "  2. Push to GitHub:"
echo "     git push origin main"
echo ""
echo "  3. Set up branch protection rules in GitHub:"
echo "     - Go to Settings → Branches"
echo "     - Add rule for 'main' branch"
echo "     - Enable 'Require status checks to pass before merging'"
echo "     - Select 'Required Checks for Main' and 'Enforce Pre-commit Checks'"
echo ""
echo "  4. Test with a pull request!"
echo ""
echo "💡 The pre-commit hook will now run automatically on each commit,"
echo "   and GitHub Actions will enforce these checks on pull requests."
