# GitHub Actions Pre-commit Setup - Complete Guide

This document provides a complete guide for setting up GitHub Actions to enforce pre-commit checks before merging into the main branch.

## 🎯 Overview

The setup includes 4 GitHub Actions workflows that work together to enforce code quality:

1. **`pr-precommit-guard.yml`** - 🛡️ **PRIMARY ENFORCER** - Blocks PRs with failing checks
2. **`required-checks.yml`** - ✅ **BRANCH PROTECTION** - Minimal required checks for merging
3. **`ci.yml`** - 🧪 **COMPREHENSIVE CI** - Full testing on multiple PostgreSQL versions
4. **`pre-commit.yml`** - 📊 **DETAILED CHECKS** - Comprehensive pre-commit validation

## 🚀 Quick Setup

### 1. Install Prerequisites and Setup
```bash
# Run the automated setup script
./.github/setup-precommit.sh
```

### 2. Commit and Push Workflows
```bash
git add .github/
git commit -m "Add GitHub Actions pre-commit workflows

- Add PR pre-commit guard to block merging on check failures
- Add required status checks for branch protection
- Add comprehensive CI with multi-version PostgreSQL testing
- Add detailed pre-commit validation workflow
- Include setup scripts and documentation"

git push origin main
```

### 3. Configure Branch Protection (CRITICAL)

Go to your GitHub repository: **Settings → Branches**

#### Add Branch Protection Rule for `main`:

**Basic Settings:**
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Require conversation resolution before merging

**Required Status Checks:**
Select these checks (they will appear after the first workflow runs):
- ✅ `Required Checks for Main` (from required-checks.yml)
- ✅ `Enforce Pre-commit Checks` (from pr-precommit-guard.yml)

**Advanced Settings:**
- ✅ Restrict pushes that create files larger than 100MB
- ✅ Include administrators (recommended)

## 🔧 How It Works

### When a PR is opened/updated:

1. **`pr-precommit-guard.yml`** runs immediately:
   - ❌ **BLOCKS merge** if formatting, linting, or docs fail
   - 💬 **Comments on PR** with helpful instructions
   - ⚡ **Fast feedback** (usually < 2 minutes)

2. **`required-checks.yml`** runs in parallel:
   - ✅ **Required for merge** (set in branch protection)
   - 🏗️ **Builds extension** to ensure it compiles
   - 📋 **Minimal essential checks**

3. **`ci.yml`** runs comprehensive tests:
   - 🐘 **Tests on PostgreSQL 13, 14, 15, 16**
   - 🔒 **Security audit**
   - 📊 **Full test suite**

### Local Development Flow:

```bash
# 1. Make changes
vim src/some_file.rs

# 2. Pre-commit hook runs automatically on commit
git commit -m "fix: improve something"
# ↳ Runs formatting, linting, docs checks automatically

# 3. Push creates PR
git push origin feature-branch
# ↳ GitHub Actions run and may block merge if issues found

# 4. Fix any issues locally
make precommit-fast  # Fix issues
git commit -m "fix: address pre-commit issues"
git push  # Try again
```

## 🛠️ Local Commands

```bash
# Fast pre-commit checks (what CI runs)
make precommit-fast

# Full pre-commit checks with tests
make precommit

# Fix specific issues
cargo fmt                    # Fix formatting
cargo clippy --fix --allow-dirty  # Fix linting
make lint-docs-fix          # Fix documentation

# Manual pre-commit run
pre-commit run --all-files
```

## 🔍 Workflow Details

### pr-precommit-guard.yml (The Enforcer 🛡️)
- **Purpose**: Block merging if basic quality checks fail
- **Runs on**: PR open/update (not drafts)
- **Checks**: Formatting, linting, documentation, pre-commit hooks
- **Features**:
  - Smart PR comments with instructions
  - Updates existing comments (no spam)
  - Concurrency control
- **Result**: ❌ Blocks merge if ANY check fails

### required-checks.yml (Branch Protection ✅)
- **Purpose**: Minimal checks required for merge
- **Runs on**: PR and push to main
- **Checks**: Format, lint, build
- **Usage**: Set as required status check in branch protection

### ci.yml (Comprehensive Testing 🧪)
- **Purpose**: Full validation and testing
- **Runs on**: Push to main/develop, PRs
- **Features**:
  - Multi-version PostgreSQL testing (13, 14, 15, 16)
  - Security audit with cargo-audit
  - Separate lint job for fast feedback
- **Matrix strategy**: Tests all supported PostgreSQL versions

### pre-commit.yml (Detailed Analysis 📊)
- **Purpose**: Comprehensive analysis and testing
- **Runs on**: Manual trigger, PR to main
- **Features**:
  - Full test suite on all PostgreSQL versions
  - Integration tests
  - Detailed reporting

## 🚨 Troubleshooting

### Common Issues:

**1. Formatting Failures:**
```bash
cargo fmt
git commit -m "fix: apply rust formatting"
```

**2. Linting Failures:**
```bash
cargo clippy --fix --allow-dirty
git commit -m "fix: address clippy warnings"
```

**3. Documentation Issues:**
```bash
make lint-docs-fix
git commit -m "fix: format documentation"
```

**4. Pre-commit Hook Issues:**
```bash
pre-commit clean
pre-commit install
```

**5. Workflow Not Running:**
- Check if workflows are enabled in repository settings
- Ensure branch protection rules are configured
- Verify required status checks are selected

### Emergency Bypass:
```bash
# Skip local pre-commit hook (NOT recommended)
git commit --no-verify -m "emergency fix"

# Note: GitHub Actions will still run and may block merge
```

## 📈 Benefits

### For Developers:
- ✅ **Immediate feedback** on code quality issues
- 🔧 **Clear instructions** on how to fix problems
- ⚡ **Fast local checks** with pre-commit hook
- 📚 **Consistent** code formatting and documentation

### For Project Maintainers:
- 🛡️ **Automatic enforcement** of code quality standards
- 🚫 **Prevents** low-quality code from entering main branch
- 📊 **Comprehensive testing** on multiple PostgreSQL versions
- 🔒 **Security auditing** with dependency checks

### For CI/CD:
- 🏗️ **Reliable builds** due to enforced quality checks
- 📈 **Faster** overall CI due to early failure detection
- 🎯 **Focused testing** on code that already passes basic checks

## 🔧 Customization

### Adding New Checks:

1. **Update `.pre-commit-config.yaml`** for local development
2. **Update workflow files** to include new checks
3. **Update Makefile targets** if needed
4. **Test thoroughly** before merging

### Modifying Thresholds:

- Edit workflow files to adjust warning/error levels
- Update branch protection rules if adding new required checks
- Document changes in this file

## 📝 Maintenance

### Regular Updates:
- Update GitHub Actions versions in workflow files
- Update pre-commit hook versions in `.pre-commit-config.yaml`
- Review and update required status checks
- Test changes in feature branches before applying to main

### Monitoring:
- Check GitHub Actions usage and performance
- Monitor for false positives or overly strict checks
- Gather developer feedback and adjust as needed

---

## 🎉 Success!

With this setup, your repository now has:
- 🛡️ **Automatic quality enforcement** on all PRs
- 🚫 **Prevention** of broken code merging to main
- 📊 **Comprehensive testing** across PostgreSQL versions
- 🔧 **Developer-friendly** local development flow
- 💬 **Helpful guidance** when issues are found

Your main branch is now protected! 🚀
