# Configuration Guide

pglinter provides several configuration options to customize the analysis behavior for your specific environment and requirements.

## Rules Management

### Viewing Rules

```sql
-- Show all available rules with their status
SELECT pglinter.show_rules();

-- Check if a specific rule is enabled
SELECT pglinter.is_rule_enabled('B001');

-- Get detailed information about a rule
SELECT pglinter.explain_rule('B002');
```

### Enabling and Disabling Rules

```sql
-- Disable a rule you don't want to check
SELECT pglinter.disable_rule('B001');

-- Re-enable a rule
SELECT pglinter.enable_rule('B001');

-- Disable multiple rules
SELECT pglinter.disable_rule('B004');

```

```sql
-- Disable all base rules
SELECT pglinter.disable_rule(rule_code)
FROM pglinter.show_rules()
WHERE rule_code LIKE 'B%';


```

### Export/Import Rules

pglinter supports exporting and importing rule configurations in YAML format, making it easy to version control, share, and modify rule settings across different environments.

#### Exporting Rules to YAML

```sql
-- Export all current rules to YAML format
SELECT pglinter.export_rules_to_yaml();
```

This will output a complete YAML structure containing:
- Metadata (export timestamp, total rules, format version)
- All rules with their current configuration (enabled status, thresholds, descriptions, etc.)

#### Saving Export to File

To save the export to a file for editing:

```bash
# Export rules and save to file
psql -d mydb -t -c "SELECT pglinter.export_rules_to_yaml();" > rules_config.yaml

# Or using the built-in file export function (if available)
# SELECT pglinter.export_rules_to_file('/tmp/rules_config.yaml');
```

#### YAML Structure

The exported YAML follows this structure:

```yaml
metadata:
  export_timestamp: "2024-01-01T12:00:00Z"
  total_rules: 25
  format_version: "1.0"
rules:
  - id: 1
    name: "Tables Without Primary Key"
    code: "B001"
    enable: true
    warning_level: 20
    error_level: 80
    scope: "BASE"
    description: "Detects tables without primary keys"
    message: "Found {0} tables without primary keys"
    fixes:
      - "Add primary key constraints to tables"
      - "Consider surrogate keys for tables without natural keys"
    q1: "SELECT COUNT(*) FROM ... WHERE ..."
    q2: null
  - id: 2
    name: "Redundant Indexes"
    code: "B002"
    enable: false
    warning_level: 15
    error_level: 50
    # ... more rule properties
```

#### Modifying Rules Configuration

Edit the exported YAML file to customize rules for your environment:

```yaml
# Example modifications:

# 1. Disable a rule
- id: 2
  code: "B002"
  enable: false  # Disable redundant index checking

# 2. Adjust thresholds
- id: 4
  code: "B004"
  warning_level: 30  # More lenient threshold
  error_level: 70    # Higher error threshold

# 3. Modify rule description
- id: 1
  code: "B001"
  description: "Custom description for primary key check"
  message: "Custom message: Found {0} tables needing primary keys"

# 4. Update fix suggestions
- id: 3
  code: "B003"
  fixes:
    - "Add indexes to foreign key columns"
    - "Consider composite indexes for multi-column FKs"
    - "Custom fix suggestion for your environment"
```

#### Importing Modified Rules

After editing the YAML file, import it back:

```sql
-- Import rules from YAML content (inline)
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-01T12:00:00Z"
  total_rules: 2
  format_version: "1.0"
rules:
  - id: 1
    name: "Tables Without Primary Key"
    code: "B001"
    enable: true
    warning_level: 30
    error_level: 70
    scope: "BASE"
    description: "Modified description"
    message: "Found {0} tables without primary keys"
    fixes:
      - "Add primary key constraints"
    q1: "SELECT COUNT(*) FROM information_schema.tables..."
    q2: null
');

-- Import rules from file
SELECT pglinter.import_rules_from_file('/path/to/modified_rules.yaml');
```

#### Environment-Specific Rule Sets

Create different YAML files for different environments:

```bash
# Development environment - more permissive
rules_dev.yaml:
- Most rules enabled but with higher thresholds
- Disable strict naming conventions
- Focus on structural issues

# Staging environment - moderate settings
rules_staging.yaml:
- All rules enabled with standard thresholds
- Test performance rules
- Validate before production

# Production environment - strict settings
rules_production.yaml:
- All critical rules enabled
- Low thresholds for early detection
- Focus on security and performance
```

#### Version Control Integration

Store rule configurations in version control:

```bash
# Initialize rule configuration in git
git add rules_production.yaml rules_staging.yaml rules_dev.yaml
git commit -m "Add pglinter rule configurations"

# Deploy environment-specific rules
psql -d production_db -c "SELECT pglinter.import_rules_from_file('/deploy/rules_production.yaml');"
psql -d staging_db -c "SELECT pglinter.import_rules_from_file('/deploy/rules_staging.yaml');"
```

#### Backup and Restore Workflow

```bash
# 1. Backup current configuration
psql -d mydb -t -c "SELECT pglinter.export_rules_to_yaml();" > backup_$(date +%Y%m%d).yaml

# 2. Modify rules as needed
# Edit the YAML file with your preferred editor

# 3. Test import in development first
psql -d dev_db -c "SELECT pglinter.import_rules_from_file('modified_rules.yaml');"

# 4. Validate configuration works
psql -d dev_db -c "SELECT pglinter.check_all();"

# 5. Apply to production
psql -d prod_db -c "SELECT pglinter.import_rules_from_file('modified_rules.yaml');"
```

#### Common Use Cases

**Customize thresholds for your database size:**
```yaml
# For large databases, increase thresholds
- code: "B004"
  warning_level: 50  # Higher threshold for seq scans
  error_level: 80

# For small databases, decrease thresholds
- code: "B001"
  warning_level: 10  # Stricter primary key checking
  error_level: 30
```

**Disable rules not applicable to your use case:**
```yaml
# Disable uppercase naming rules for legacy systems
- code: "B005"
  enable: false
- code: "B006"
  enable: false

# Disable cross-schema FK rules for multi-tenant systems
- code: "B008"
  enable: false
```

**Add custom fix suggestions:**
```yaml
- code: "B001"
  fixes:
    - "Run migration script: add_missing_primary_keys.sql"
    - "Contact DBA team for legacy table primary keys"
    - "See company wiki: Primary Key Standards"
```

#### Validation and Testing

Always validate imported configurations:

```sql
-- Verify rules were imported correctly
SELECT code, enable, warning_level, error_level
FROM pglinter.rules
WHERE code IN ('B001', 'B002', 'B003')
ORDER BY code;

-- Test rule execution
SELECT pglinter.perform_base_check();

-- Check for any import errors in PostgreSQL logs
```

## Output Configuration

### File Output

```sql
-- Save results to a specific file
SELECT pglinter.perform_base_check('/var/log/pglinter/results.sarif');

-- Use timestamp in filename
SELECT pglinter.perform_base_check(
    '/var/log/pglinter/results_' || to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') || '.sarif'
);
```

### Console Output

```sql
-- Output results to console (no file parameter)
SELECT pglinter.perform_base_check();

-- Format output for better readability
\x on
SELECT pglinter.perform_base_check();
\x off
```

## Environment-Specific Configuration

### Development Environment

For development, you might want to be more permissive:

```sql
-- Disable strict rules that might not apply during development
SELECT pglinter.disable_rule('B005'); -- Public schema security
SELECT pglinter.disable_rule('T009'); -- Role grants
SELECT pglinter.disable_rule('T010'); -- Reserved keywords
```

### Production Environment

For production, enable all security and performance rules:

```sql
-- Ensure all critical rules are enabled
SELECT pglinter.enable_rule('B001'); -- Primary keys
SELECT pglinter.enable_rule('B002'); -- Redundant indexes
SELECT pglinter.enable_rule('B003'); -- FK indexing
SELECT pglinter.enable_rule('B004'); -- Unused indexes
SELECT pglinter.enable_rule('B005'); -- Schema security
SELECT pglinter.enable_rule('C001'); -- Memory configuration
SELECT pglinter.enable_rule('C002'); -- pg_hba security
SELECT pglinter.enable_rule('C003'); -- MD5 password encryption
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

pglinter stores configuration in PostgreSQL tables:

```sql
-- View rule configuration table
\d pglinter.rules

-- Backup configuration
pg_dump -t pglinter.rules mydb > pglinter_config_backup.sql

-- Restore configuration
psql -d mydb -f pglinter_config_backup.sql
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
FROM pglinter.show_rules()
ORDER BY rule_code;

-- Test a specific rule
SELECT pglinter.perform_base_check() WHERE rule_code = 'B001';
```

### Reset to Defaults

```sql
-- Re-enable all rules (default state)
SELECT pglinter.enable_rule(rule_code)
FROM pglinter.show_rules();
```

### Configuration Conflicts

If you encounter issues:

1. Check PostgreSQL logs for errors
2. Verify extension is properly installed
3. Ensure database user has necessary permissions
4. Test with minimal configuration first
