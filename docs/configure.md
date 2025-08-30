# Configuration Guide

DBLinter provides several configuration options to customize the analysis behavior for your specific environment and requirements.

## Rule Management

### Viewing Rules

```sql
-- Show all available rules with their status
SELECT dblinter.show_rules();

-- Check if a specific rule is enabled
SELECT dblinter.is_rule_enabled('B001');

-- Get detailed information about a rule
SELECT dblinter.explain_rule('B002');
```

### Enabling and Disabling Rules

```sql
-- Disable a rule you don't want to check
SELECT dblinter.disable_rule('B001');

-- Re-enable a rule
SELECT dblinter.enable_rule('B001');

-- Disable multiple rules
SELECT dblinter.disable_rule('B004');
SELECT dblinter.disable_rule('T007');
```

### Rule Categories

You can manage rules by category:

```sql
-- Disable all base rules
SELECT dblinter.disable_rule(rule_code)
FROM dblinter.show_rules()
WHERE rule_code LIKE 'B%';

-- Enable only table rules
SELECT dblinter.enable_rule(rule_code)
FROM dblinter.show_rules()
WHERE rule_code LIKE 'T%';
```

## Threshold Configuration

Many rules have configurable thresholds. These are stored in the `dblinter.rules` table:

### Viewing Current Thresholds

```sql
-- View rule configuration
SELECT rule_code, description, enabled, fixes
FROM dblinter.rules
WHERE rule_code = 'B001';
```

### Common Threshold Adjustments

#### B001: Tables without primary keys
Default threshold: 10% of tables without primary keys triggers warning

```sql
-- The threshold is currently hardcoded in the rule implementation
-- Future versions will support configurable thresholds
```

#### T005: High sequential scan usage
Default threshold: 10,000 average tuples read per sequential scan

```sql
-- This threshold is currently hardcoded
-- Contact support for custom threshold requirements
```

#### T007: Unused indexes
Default threshold: 1MB minimum size to consider an index "unused"

```sql
-- Size threshold is currently hardcoded
-- Future versions will support configuration
```

## Output Configuration

### File Output

```sql
-- Save results to a specific file
SELECT dblinter.perform_base_check('/var/log/dblinter/results.sarif');

-- Use timestamp in filename
SELECT dblinter.perform_base_check(
    '/var/log/dblinter/results_' || to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') || '.sarif'
);
```

### Console Output

```sql
-- Output results to console (no file parameter)
SELECT dblinter.perform_base_check();

-- Format output for better readability
\x on
SELECT dblinter.perform_base_check();
\x off
```

## Environment-Specific Configuration

### Development Environment

For development, you might want to be more permissive:

```sql
-- Disable strict rules that might not apply during development
SELECT dblinter.disable_rule('B005'); -- Public schema security
SELECT dblinter.disable_rule('T009'); -- Role grants
SELECT dblinter.disable_rule('T010'); -- Reserved keywords
```

### Production Environment

For production, enable all security and performance rules:

```sql
-- Ensure all critical rules are enabled
SELECT dblinter.enable_rule('B001'); -- Primary keys
SELECT dblinter.enable_rule('B002'); -- Redundant indexes
SELECT dblinter.enable_rule('B003'); -- FK indexing
SELECT dblinter.enable_rule('B004'); -- Unused indexes
SELECT dblinter.enable_rule('B005'); -- Schema security
SELECT dblinter.enable_rule('C001'); -- Memory configuration
SELECT dblinter.enable_rule('C002'); -- pg_hba security
```

### Testing Environment

For testing environments, focus on data integrity:

```sql
-- Enable data integrity rules
SELECT dblinter.enable_rule('B001'); -- Primary keys
SELECT dblinter.enable_rule('T001'); -- Table primary keys
SELECT dblinter.enable_rule('T004'); -- FK indexing
SELECT dblinter.enable_rule('T008'); -- FK type mismatches

-- Disable performance rules that might not be relevant
SELECT dblinter.disable_rule('B004'); -- Unused indexes
SELECT dblinter.disable_rule('T007'); -- Unused indexes
SELECT dblinter.disable_rule('T005'); -- Sequential scans
```

## Automated Configuration

### Configuration Scripts

Create reusable configuration scripts for different environments:

```sql
-- config/development.sql
\echo 'Configuring DBLinter for development environment...'

SELECT dblinter.disable_rule('B005');
SELECT dblinter.disable_rule('T009');
SELECT dblinter.disable_rule('T010');
SELECT dblinter.disable_rule('C002');

\echo 'Development configuration complete.'
```

```sql
-- config/production.sql
\echo 'Configuring DBLinter for production environment...'

-- Enable all rules
SELECT dblinter.enable_rule(rule_code)
FROM dblinter.show_rules();

\echo 'Production configuration complete.'
```

### Apply Configuration

```bash
# Apply development configuration
psql -d mydb -f config/development.sql

# Apply production configuration
psql -d mydb -f config/production.sql
```

## Integration with CI/CD

### GitHub Actions

```yaml
# .github/workflows/dblinter.yml
name: Database Linting
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v3

    - name: Install DBLinter
      run: |
        # Install extension
        psql -h localhost -U postgres -d postgres -c "CREATE EXTENSION dblinter;"

    - name: Run Database Analysis
      run: |
        # Apply production configuration
        psql -h localhost -U postgres -d postgres -f config/production.sql

        # Run analysis
        psql -h localhost -U postgres -d postgres -c "SELECT dblinter.perform_base_check('/tmp/results.sarif');"

    - name: Upload SARIF results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: /tmp/results.sarif
```

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - lint

db-lint:
  stage: lint
  image: postgres:14
  services:
    - postgres:14
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
  script:
    - psql -c "CREATE EXTENSION dblinter;"
    - psql -f config/ci.sql
    - psql -c "SELECT dblinter.perform_base_check('/tmp/results.sarif');"
  artifacts:
    reports:
      sast: /tmp/results.sarif
```

## Advanced Configuration

### Custom Rule Implementations

Future versions will support custom rules. The architecture supports:

```rust
// Custom rule example (future feature)
pub struct CustomRule {
    threshold: i64,
    enabled: bool,
}

impl DatabaseRule for CustomRule {
    fn execute(&self) -> Result<Option<RuleResult>, String> {
        // Custom rule logic
    }
}
```

### Configuration Database

DBLinter stores configuration in PostgreSQL tables:

```sql
-- View rule configuration table
\d dblinter.rules

-- Backup configuration
pg_dump -t dblinter.rules mydb > dblinter_config_backup.sql

-- Restore configuration
psql -d mydb -f dblinter_config_backup.sql
```

## Best Practices

1. **Environment-Specific Config**: Use different configurations for dev/test/prod
2. **Version Control**: Store configuration scripts in version control
3. **Regular Reviews**: Periodically review and adjust thresholds
4. **Documentation**: Document any custom configurations for your team
5. **Testing**: Test configuration changes in non-production environments first

## Troubleshooting Configuration

### Check Current Configuration

```sql
-- Verify which rules are enabled
SELECT rule_code, enabled
FROM dblinter.show_rules()
ORDER BY rule_code;

-- Test a specific rule
SELECT dblinter.perform_base_check() WHERE rule_code = 'B001';
```

### Reset to Defaults

```sql
-- Re-enable all rules (default state)
SELECT dblinter.enable_rule(rule_code)
FROM dblinter.show_rules();
```

### Configuration Conflicts

If you encounter issues:

1. Check PostgreSQL logs for errors
2. Verify extension is properly installed
3. Ensure database user has necessary permissions
4. Test with minimal configuration first

For additional help, see the [Troubleshooting Guide](troubleshooting.md).
