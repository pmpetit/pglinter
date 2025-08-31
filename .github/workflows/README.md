# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the pglinter project.

## Workflows Overview

### 1. `pre-commit.yml` - Comprehensive Pre-commit Checks
- **Trigger**: Pull requests to main, manual dispatch
- **Purpose**: Run comprehensive pre-commit checks including tests on multiple PostgreSQL versions
- **Includes**: Formatting, linting, documentation, unit tests, integration tests
- **PostgreSQL versions**: 13, 14, 15, 16

### 2. `pr-precommit-guard.yml` - PR Pre-commit Guard 🛡️
- **Trigger**: Pull requests to main (blocks merging if checks fail)
- **Purpose**: Enforce pre-commit standards before merging
- **Features**:
  - Comments on PRs with status and helpful instructions
  - Skips draft PRs
  - Fast feedback loop
- **Blocks merge if**: Formatting, linting, or documentation issues

### 3. `required-checks.yml` - Required Status Check ✅
- **Trigger**: Pull requests and pushes to main
- **Purpose**: Minimal set of checks required for merging
- **Recommended**: Set as required status check in branch protection rules

### 4. `ci.yml` - Continuous Integration
- **Trigger**: Push to main/develop, PRs to main/develop
- **Purpose**: Comprehensive testing and validation
- **Includes**: Multi-version PostgreSQL testing, security audit

## Setting Up Branch Protection

To enforce pre-commit checks before merging to main:

1. Go to your repository Settings → Branches
2. Add a rule for the `main` branch
3. Enable "Require status checks to pass before merging"
4. Select these required checks:
   - `Required Checks for Main` (from required-checks.yml)
   - `Enforce Pre-commit Checks` (from pr-precommit-guard.yml)

## Local Development Setup

### Install Pre-commit Hook (Recommended)
```bash
# Install the git pre-commit hook
make install-precommit-hook

# This will automatically run checks on each commit
```

### Manual Pre-commit Checks
```bash
# Fast checks (formatting, linting, docs)
make precommit-fast

# Full checks (includes tests)
make precommit

# Individual checks
make fmt-check          # Check formatting
make lint              # Run clippy
make lint-docs         # Check documentation
```

### Pre-commit Configuration
The pre-commit configuration is in `.pre-commit-config.yaml` and includes:
- Trailing whitespace removal
- End-of-file fixing
- Large file checking
- Code spelling (codespell)
- Markdown linting
- Rust formatting (rustfmt)

## Workflow Features

### Smart Comments
The PR guard workflow automatically comments on pull requests with:
- ✅ Success messages when all checks pass
- ❌ Helpful instructions when checks fail
- Updates existing comments instead of spamming

### Concurrency Control
All workflows use concurrency groups to:
- Cancel in-progress runs when new commits are pushed
- Prevent resource waste
- Provide faster feedback

### Caching
Workflows include intelligent caching for:
- Rust compilation artifacts
- Pre-commit hooks
- Node.js/Python dependencies

## Troubleshooting

### Common Issues and Fixes

**Formatting Issues:**
```bash
cargo fmt
```

**Linting Issues:**
```bash
cargo clippy --fix --allow-dirty
```

**Documentation Issues:**
```bash
markdownlint --fix docs/ README.md
```

**Pre-commit Hook Issues:**
```bash
pre-commit clean
pre-commit install
```

### Skipping Checks (Emergency Use)
```bash
# Skip pre-commit hook for emergency commits
git commit --no-verify -m "emergency fix"
```

**Note**: Emergency commits will still be checked by CI and may be blocked from merging.

## Maintenance

### Updating Dependencies
- Update `.pre-commit-config.yaml` hook versions regularly
- Update GitHub Actions versions in workflow files
- Test changes in a feature branch first

### Adding New Checks
1. Add to `.pre-commit-config.yaml` for local development
2. Update relevant workflow files
3. Update this README
4. Test thoroughly before merging
