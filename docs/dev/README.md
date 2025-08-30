# Development Guide

Guide for contributing to pglinter development.

## Quick Start for Contributors

1. **Setup Development Environment** - See [Development Environment Setup](#development-environment-setup)
2. **Install Pre-commit Hooks** - `make install-precommit-hook` (recommended)
3. **Run Quality Checks** - `make precommit-fast` before committing
4. **Complete Guide** - See [Pre-commit System](precommit.md) for details

## Development Environment Setup

### Prerequisites

- Rust 1.70+
- PostgreSQL 13, 14, 15, or 16
- PostgreSQL development headers
- Git

### Initial Setup

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Install cargo-pgrx
cargo install cargo-pgrx

# Initialize pgrx for your PostgreSQL version
cargo pgrx init

# Clone the repository
git clone https://github.com/yourorg/pglinter.git
cd pglinter

# Build the extension
cargo pgrx package

# Install for development
cargo pgrx install --debug
```

### Development Workflow

```bash
# Make changes to source code
# ...

# Rebuild and reinstall
cargo pgrx install --debug

# Test your changes
cargo pgrx test

# Run specific tests
cargo test test_b001_rule
```

## Project Structure

```text
pglinter/
├── Cargo.toml              # Rust package configuration
├── pglinter.control        # PostgreSQL extension control file
├── src/
│   ├── lib.rs              # Main library entry point
│   ├── rules_engine.rs     # Core rule engine implementation
│   └── bin/
│       └── pgrx_embed.rs   # pgrx embedding binary
├── sql/
│   └── rules.sql           # SQL for rules table and data
├── tests/
│   ├── sql/                # SQL test files
│   └── expected/           # Expected test output
├── docs/                   # Documentation
└── target/                 # Build artifacts
```

### Key Files

- **`src/lib.rs`**: Defines PostgreSQL function exports
- **`src/rules_engine.rs`**: Core rule implementation logic
- **`sql/rules.sql`**: Rule metadata and configuration
- **`tests/sql/`**: Regression test SQL files

## Adding New Rules

### Rule Categories

Rules are organized by category:
- **B-series**: Base/Database-wide rules
- **C-series**: Cluster configuration rules
- **T-series**: Table-specific rules
- **S-series**: Schema-level rules

### Implementation Steps

1. **Add Rule Function**

In `src/rules_engine.rs`, add your rule function:

```rust
fn execute_b007_rule() -> Result<Option<RuleResult>, String> {
    // Your rule logic here
    let query = "
        SELECT count(*)
        FROM your_analysis_query
        WHERE your_conditions";

    let result: Result<Option<RuleResult>, spi::SpiError> = Spi::connect(|client| {
        let count: i64 = client
            .select(query, None, &[])?
            .first()
            .get::<i64>(1)?
            .unwrap_or(0);

        if count > 0 {
            return Ok(Some(RuleResult {
                ruleid: "B007".to_string(),
                level: "warning".to_string(),
                message: format!("Found {} issues", count),
                count: Some(count),
            }));
        }

        Ok(None)
    });

    match result {
        Ok(res) => Ok(res),
        Err(e) => Err(format!("Database error: {e}"))
    }
}
```

2. **Register Rule in Engine**

Add your rule to the appropriate function in `src/rules_engine.rs`:

```rust
pub fn execute_base_rules() -> Result<Vec<RuleResult>, String> {
    let mut results = Vec::new();

    // ... existing rules ...

    // B007: Your new rule
    if is_rule_enabled("B007").unwrap_or(true) {
        match execute_b007_rule() {
            Ok(Some(result)) => results.push(result),
            Ok(None) => {},
            Err(e) => return Err(format!("B007 failed: {e}"))
        }
    }

    Ok(results)
}
```

3. **Add Rule Metadata**

Add rule information to `sql/rules.sql`:

```sql
INSERT INTO pglinter.rules (rule_code, description, enabled, fixes) VALUES
('B007', 'Your rule description', TRUE, ARRAY[
    'Fix suggestion 1',
    'Fix suggestion 2',
    'Fix suggestion 3'
]);
```

4. **Create Tests**

Create a test file `tests/sql/b007.sql`:

```sql
-- Test for B007 rule
BEGIN;

-- Create test data that should trigger the rule
CREATE TABLE test_table (...);

CREATE EXTENSION IF NOT EXISTS pglinter;

-- Test the rule
SELECT pglinter.perform_base_check();

-- Test rule management
SELECT pglinter.explain_rule('B007');
SELECT pglinter.is_rule_enabled('B007');

-- Clean up
DROP TABLE test_table;

ROLLBACK;
```

Create expected output `tests/expected/b007.out`:

```text
BEGIN
-- Expected output from your test
ROLLBACK
```

5. **Run Tests**

```bash
# Run your specific test
cargo pgrx test b007

# Run all tests
cargo pgrx test
```

### Rule Implementation Guidelines

1. **Use Consistent Naming**: Follow the pattern `execute_RULEID_rule()`
1. **Handle Errors Gracefully**: Return descriptive error messages
3. **Optimize Queries**: Use efficient PostgreSQL queries
2. **Consider Performance**: Large databases should be handled efficiently
3. **Document Thresholds**: Make configurable values clear

## Testing

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rule_execution() {
        // Test your rule logic
        assert_eq!(expected, actual);
    }
}
```

### Integration Tests

Integration tests use PostgreSQL and are located in `tests/sql/`:

```sql
-- tests/sql/my_test.sql
BEGIN;

-- Setup test data
CREATE TABLE test_table (id INT);

-- Create extension
CREATE EXTENSION IF NOT EXISTS pglinter;

-- Test functionality
SELECT pglinter.perform_base_check();

-- Verify results
-- Add specific assertions

ROLLBACK;
```

### Running Tests

```bash
# Run all tests
cargo pgrx test

# Run specific test
cargo pgrx test my_test

# Run with specific PostgreSQL version
cargo pgrx test pg14 my_test

# Run tests in verbose mode
cargo pgrx test --verbose
```

## Code Style and Standards

### Rust Code Style

Follow standard Rust conventions:

```rust
// Use descriptive function names
fn execute_foreign_key_type_mismatch_rule() -> Result<Option<RuleResult>, String> {
    // Use proper error handling
    let result = match some_operation() {
        Ok(value) => value,
        Err(e) => return Err(format!("Operation failed: {e}"))
    };

    // Use clear variable names
    let foreign_key_mismatches = analyze_foreign_keys()?;

    // Format messages consistently
    Ok(Some(RuleResult {
        ruleid: "T008".to_string(),
        level: "error".to_string(),
        message: format!("Found {} foreign key type mismatches", count),
        count: Some(count),
    }))
}
```

### SQL Style

Use consistent SQL formatting:

```sql
-- Use clear, readable queries
SELECT
    tc.table_schema,
    tc.table_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
ORDER BY tc.table_schema, tc.table_name;
```

### Documentation Standards

- Document all public functions
- Include examples in documentation
- Keep README.md updated
- Add inline comments for complex logic

## Performance Considerations

### Query Optimization

1. **Use Appropriate Indexes**: Ensure your queries can use existing indexes
2. **Limit Scope**: Filter out system schemas early
3. **Avoid N+1 Queries**: Use JOINs instead of multiple queries
1. **Consider Large Tables**: Test with realistic data sizes

### Memory Management

```rust
// Prefer iterating over collecting when possible
for row in client.select(query, None, &[])? {
    // Process row immediately
    process_row(row)?;
}

// Instead of:
let all_rows: Vec<_> = client.select(query, None, &[])?.collect();
```

### Caching Strategies

Future versions may include caching. Consider:
- Rule result caching
- Metadata caching
- Query plan caching

## Debugging

### Enable Logging

```rust
use pgrx::prelude::*;

// Add debug logging
log!("Processing rule B001 with {} tables", table_count);
```

### Database Debugging

```sql
-- Enable query logging
SET log_statement = 'all';
SET log_duration = on;

-- Run your analysis
SELECT pglinter.perform_base_check();
```

### Rust Debugging

```bash
# Build with debug symbols
cargo pgrx install --debug

# Use GDB (if needed)
gdb postgres
```

## Continuous Integration

### Pre-commit Checks

The project includes an automated pre-commit system accessible via Makefile targets:

```bash
# Install the git pre-commit hook (recommended for contributors)
make install-precommit-hook

# Run all pre-commit checks manually
make precommit

# Run fast pre-commit checks (skip tests)
make precommit-fast
```

## Automated Checks Include

- Rust code formatting validation (`cargo fmt --check`)
- Rust code linting (`cargo clippy`)
- Markdown documentation linting
- Unit tests (in full `precommit` target)

## Manual Git Hook Example
If you prefer a custom git hook, you can create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Custom pre-commit hook

# Format code
cargo fmt --check || exit 1

# Run clippy
cargo clippy -- -D warnings || exit 1

# Run tests
cargo pgrx test || exit 1

echo "All checks passed!"
```

### GitHub Actions

The project uses GitHub Actions for CI:

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        postgres: [13, 14, 15, 16]

    steps:
    - uses: actions/checkout@v3

    - name: Install Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable

    - name: Install pgrx
      run: cargo install cargo-pgrx

    - name: Test
      run: |
        cargo pgrx init --pg${{ matrix.postgres }}
        cargo pgrx test pg${{ matrix.postgres }}
```

## Release Process

### Version Management

1. Update version in `Cargo.toml`
2. Update version in `pglinter.control`
3. Update CHANGELOG.md
4. Tag the release

### Building Releases

```bash
# Build for multiple PostgreSQL versions
cargo pgrx package --pg13 --pg14 --pg15 --pg16

# Create distribution packages
# (Process varies by distribution)
```

## Contributing Guidelines

### Pull Request Process

1. **Fork the Repository**
2. **Create Feature Branch**: `git checkout -b feature/new-rule-b008`
3. **Make Changes**: Implement your feature
4. **Add Tests**: Ensure good test coverage
5. **Update Documentation**: Update relevant docs
6. **Submit Pull Request**: With detailed description

### Code Review Checklist

- [ ] Code follows project style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] Performance impact is considered
- [ ] Error handling is appropriate
- [ ] Security implications are reviewed

### Issue Reporting

When reporting issues:

1. **Use Issue Templates**: Fill out the provided template
2. **Include Environment Details**: OS, PostgreSQL version, etc.
3. **Provide Reproduction Steps**: Clear steps to reproduce
4. **Include Logs**: Relevant error messages and logs

## Development Tools

### Useful Commands

```bash
# Format code
cargo fmt

# Lint code
cargo clippy

# Check for security vulnerabilities
cargo audit

# Generate documentation
cargo doc --open

# Profile performance
cargo pgrx run --release
```

### IDE Setup

#### VS Code

Recommended extensions:
- rust-analyzer
- PostgreSQL syntax highlighting
- SARIF Viewer

#### Vim/Neovim

Useful plugins:
- coc-rust-analyzer
- vim-pgsql
- ale (for linting)

## Resources

- **pgrx Documentation**: [pgrx Guide](https://github.com/pgcentralfoundation/pgrx)
- **PostgreSQL Documentation**: [PostgreSQL Docs](https://postgresql.org/docs/)
- **Rust Documentation**: [Rust Book](https://doc.rust-lang.org/book/)
- **SARIF Specification**: [SARIF Standard](https://sarifweb.azurewebsites.net/)

## Getting Help

- **Discord**: Join the pgrx Discord server
- **GitHub Discussions**: Ask questions in project discussions
- **Stack Overflow**: Tag questions with `pglinter` and `postgresql`
- **PostgreSQL Slack**: #extensions channel
