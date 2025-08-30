# Pre-commit System

This project includes a comprehensive pre-commit system to ensure code quality and consistency.

## Quick Setup

```bash
# Install the git pre-commit hook (runs automatically on git commit)
make install-precommit-hook
```

## Manual Usage

```bash
# Run all pre-commit checks (includes tests - slower but comprehensive)
make precommit

# Run fast pre-commit checks (skip tests - good for rapid development)
make precommit-fast
```

## Individual Components

```bash
# Code formatting
make fmt              # Apply formatting
make fmt-check        # Check formatting without changes

# Code linting
make lint             # Run Rust clippy linting

# Documentation
make lint-docs        # Lint markdown documentation
make lint-docs-fix    # Lint and auto-fix markdown files
make spell-check      # Check spelling in docs

# Security
make audit            # Run security audit on dependencies

# Testing
make test             # Run unit tests
make test-all         # Run all integration tests
```

## What Gets Checked

### ✅ Rust Code Formatting
- Validates code follows `cargo fmt` standards
- Ensures consistent formatting across the codebase

### ✅ Rust Code Linting
- Runs `cargo clippy` to catch common issues
- Enforces Rust best practices and idioms

### ✅ Documentation Linting
- Checks markdown files for style consistency using `rumdl` (Rust MarkDown Linter)
- Provides comprehensive markdown validation and auto-fix capabilities

### ✅ Unit Tests (full `precommit` only)
- Runs all Rust unit tests
- Validates core functionality works correctly

## Integration with Git

Once the hook is installed with `make install-precommit-hook`, every `git commit` will automatically run `make precommit-fast` to catch issues before they're committed.

## To bypass the hook temporarily

```bash
git commit --no-verify -m "Your commit message"
```

## CI/CD Integration

The same checks can be integrated into CI/CD pipelines:

```bash
# In your CI script
make precommit
```

## Troubleshooting

### Formatting Issues

```bash
# Fix formatting automatically
make fmt

# Then commit
git add .
git commit -m "Fix formatting"
```

### Linting Issues

```bash
# See detailed linting output
make lint

# Fix issues and retry
git add .
git commit -m "Fix linting issues"
```

### Test Failures

```bash
# Run tests individually to debug
make test

# Or run specific tests
make test-b001
```

### Markdown Linting Issues

```bash
# Auto-fix many markdown formatting issues
make lint-docs-fix

# Check what issues remain
make lint-docs
```

## Configuration

### Markdown Linting
- Configured via `.rumdl.toml`
- Excludes MD024 (duplicate headings) rule
- Allows longer lines in code blocks and tables

### Rust Linting
- Uses standard `cargo clippy` configuration
- Can be customized via `clippy.toml` if needed

## Benefits

- **Consistent Code Quality**: Ensures all code meets project standards
- **Early Issue Detection**: Catches problems before they reach the repository
- **Reduced Review Time**: Automated checks mean reviewers can focus on logic
- **Documentation Quality**: Keeps documentation formatted and consistent
- **Security**: Regular audits catch vulnerable dependencies
