# PGLinter Examples

This document provides practical examples of using PGLinter to analyze PostgreSQL databases for potential issues, performance problems, and best practice violations. All examples are based on the regression tests in `tests/sql/`.

## Table of Contents

- [Getting Started](#getting-started)
- [Base Rules (B-Series)](#base-rules-b-series)
- [Schema Rules (S-Series)](#schema-rules-s-series)
- [Rule Management](#rule-management)
- [Integration Testing](#integration-testing)
- [Output Options](#output-options)

## Getting Started

First, install the extension in your PostgreSQL database:

```sql
CREATE EXTENSION pglinter;
```

### Basic Usage

Run all enabled checks:

```sql
SELECT * FROM pglinter.get_violations();
```

Filter violations for a specific rule:

```sql
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B001';
```

## Base Rules (B-Series)

### B001: Tables Without Primary Keys

**Problem**: Tables without primary keys can cause replication issues and make data management difficult.

```sql
-- Create a problematic table
CREATE TABLE my_table_without_pk (
    id INT,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE
);

-- Check for tables without primary keys
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B001';

-- Get detailed explanation
SELECT pglinter.explain_rule('B001');
```

**Fix**: Add a primary key to the table:

```sql
ALTER TABLE my_table_without_pk ADD PRIMARY KEY (id);
```

### B002: Redundant Indexes

**Problem**: Redundant indexes waste storage space and slow down write operations.

```sql
-- Create table with redundant indexes
CREATE TABLE test_table_with_redundant_indexes (
    id INT PRIMARY KEY,
    name TEXT,
    email VARCHAR(255),
    status VARCHAR(50)
);

-- Create redundant indexes
CREATE INDEX idx_name_1 ON test_table_with_redundant_indexes (name);
CREATE INDEX idx_name_2 ON test_table_with_redundant_indexes (name); -- redundant!

-- Create table with unique constraint and redundant index
CREATE TABLE orders_table_with_constraint (
    order_id SERIAL PRIMARY KEY,
    customer_id INT UNIQUE,
    product_name VARCHAR(255)
);

-- This index is redundant with the unique constraint above
CREATE INDEX my_idx_customer ON orders_table_with_constraint (customer_id);

-- Check for redundant indexes
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B002';
```

**Fix**: Drop the redundant indexes:

```sql
DROP INDEX idx_name_2;
DROP INDEX my_idx_customer; -- The unique constraint already provides an index
```

### B003: Foreign Keys Without Indexes

**Problem**: Foreign key columns without indexes can cause performance issues during joins and constraint checks.

```sql
-- Create tables with foreign key relationships
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name TEXT
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);
-- Note: customer_id doesn't have an index, which can cause performance issues

-- Check for unindexed foreign keys
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B003';
```

**Fix**: Add indexes to foreign key columns:

```sql
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
```

### B004: Unused Indexes

**Problem**: Unused indexes consume storage and slow down writes without providing query benefits.

```sql
-- Create table with potentially unused index
CREATE TABLE test_unused_index (
    id SERIAL PRIMARY KEY,
    name TEXT,
    status TEXT
);

CREATE INDEX idx_unused_status ON test_unused_index(status);
-- This index might be unused if no queries actually use it

-- Check for unused indexes
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B004';
```

### B005: Uppercase Table/Column Names

**Problem**: Uppercase identifiers require quoting and can cause portability issues.

```sql
-- Create tables with uppercase names (problematic)
CREATE TABLE "UPPERCASE_TABLE" (
    "ID" INT PRIMARY KEY,
    "NAME" TEXT
);

-- Check for uppercase identifiers
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B005';
```

**Fix**: Use lowercase identifiers:

```sql
CREATE TABLE lowercase_table (
    id INT PRIMARY KEY,
    name TEXT
);
```

## Schema Rules (S-Series)

### S001: Schema Without Default Role Grants

**Problem**: Schemas without proper role grants can cause access issues.

```sql
-- Create problematic schema setup
CREATE ROLE s001_owner LOGIN;
CREATE SCHEMA s001_schema AUTHORIZATION s001_owner;
-- No default privileges granted

-- Check schema security
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'S001';

-- Cleanup
DROP SCHEMA s001_schema CASCADE;
DROP ROLE s001_owner;
```

### S002: Schema Names with Environment Prefixes/Suffixes

**Problem**: Schema names containing environment indicators (dev, test, prod) in production can be confusing.

```sql
-- Problematic schema names
CREATE SCHEMA dev_application;
CREATE SCHEMA test_schema;
CREATE SCHEMA prod_data;

-- Check schema naming conventions
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'S002';
```

### S003: Unsecured Public Schema

**Problem**: The public schema with default permissions can be a security risk.

```sql
-- Check public schema security
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'S003';

-- View current public schema permissions
SELECT * FROM information_schema.usage_privileges WHERE object_name = 'public';
```

## Rule Management

### Viewing Available Rules

```sql
-- List all available rules with their status
SELECT pglinter.list_rules();

-- Show detailed rule status
SELECT pglinter.show_rules();

-- Get explanation for a specific rule
SELECT pglinter.explain_rule('B001');
```

### Enabling and Disabling Rules

```sql
-- Check if a rule is enabled
SELECT pglinter.is_rule_enabled('B001');

-- Disable a specific rule
SELECT pglinter.disable_rule('B001');

-- Enable a specific rule
SELECT pglinter.enable_rule('B001');

-- Disable all rules (useful for testing)
SELECT pglinter.disable_all_rules();

-- Enable all rules
SELECT pglinter.enable_all_rules();
```

### Rule Level Management

```sql



```

### Rule Configuration Import/Export

```sql
-- Export current rule configuration to YAML
SELECT pglinter.export_rules_to_yaml();

-- Export to file
SELECT pglinter.export_rules_to_file('/tmp/pglinter_config.yaml');

-- Import from YAML string
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 2
  format_version: "1.0"
rules:
  - code: "B001"
    enabled: true
');

-- Import from file
SELECT pglinter.import_rules_from_file('/tmp/pglinter_config.yaml');
```

## Integration Testing

Run comprehensive checks across multiple rule categories:

```sql
-- Create diverse test scenario
CREATE TABLE users_no_pk (
    id INT,  -- B001: No primary key
    username TEXT,
    email TEXT
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    category TEXT,
    price NUMERIC
);

-- Create redundant indexes (B002)
CREATE INDEX idx_name_1 ON products (name);
CREATE INDEX idx_name_2 ON products (name); -- redundant

-- Create foreign key without index (B003)
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT,  -- Foreign key without index
    product_id INT,
    order_date DATE,
    FOREIGN KEY (user_id) REFERENCES users_no_pk(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Run comprehensive check
SELECT * FROM pglinter.get_violations();

-- Filter violations for specific rule categories
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B001'; -- Tables without PKs
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B002'; -- Redundant indexes
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B003'; -- Unindexed foreign keys
```

## Output Options

### Violations Table

```sql
-- Get all violations
SELECT * FROM pglinter.get_violations();

-- Count violations per rule
SELECT rule_code, count(*) AS violation_count
FROM pglinter.get_violations()
GROUP BY rule_code
ORDER BY rule_code;

-- Check for violations with explanation
SELECT v.rule_code, v.message
FROM pglinter.get_violations() v;
```

### Rule Details

```sql
-- Show q4 violation-location query used by a rule (for debugging)
SELECT pglinter.show_rule_queries('B001');

```

## Best Practices

1. **Regular Monitoring**: Run PGLinter regularly as part of your database maintenance routine
2. **Rule Customization**: Adjust warning and error levels based on your environment's requirements
3. **Selective Checking**: Use specific rule checks during development, comprehensive checks in CI/CD
4. **Documentation**: Export rule configurations to maintain consistency across environments
5. **Integration**: Include PGLinter checks in your deployment pipeline

## Example CI/CD Integration

```bash
# In your CI/CD pipeline
VIOLATIONS=$(psql -d your_database -t -c "SELECT count(*) FROM pglinter.get_violations();")

# Check if any violations were found
if [ "$VIOLATIONS" -gt 0 ]; then
    echo "Database violations found:"
    psql -d your_database -c "SELECT * FROM pglinter.get_violations();"
    exit 1
fi
```

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure the database user has appropriate permissions to query system catalogs
2. **Extension Not Found**: Make sure PGLinter is properly installed and the extension is created
3. **Rule Not Found**: Verify rule codes are correct (case-sensitive)

### Debugging

```sql
-- Enable verbose logging for specific rule
SELECT pglinter.explain_rule('B001');

-- Check rule status
SELECT pglinter.is_rule_enabled('B001');

-- View all available rules
SELECT pglinter.list_rules();
```

For more detailed information about specific rules, see the individual rule documentation in the `docs/rules/` directory.
