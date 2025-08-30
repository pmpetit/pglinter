# Quick Start Tutorial

Get started with DBLinter in 15 minutes! This tutorial will walk you through installation, basic usage, and interpreting results.

## Prerequisites

- PostgreSQL 13+ running
- Basic familiarity with PostgreSQL and SQL
- Admin access to your database

## Step 1: Installation

### Install the Extension

```bash
# Clone and build (replace with actual installation method)
git clone https://github.com/yourorg/pg_linter.git
cd dblinter
cargo pgrx package
sudo cargo pgrx install
```

### Enable in Your Database

```sql
-- Connect to your database
psql -d your_database

-- Create the extension
CREATE EXTENSION pg_linter;

-- Verify installation
\dx dblinter
```

You should see output like:
```
                List of installed extensions
   Name   | Version |   Schema   |        Description
----------+---------+------------+--------------------------
 dblinter |   1.0   | dblinter   | Database linting and analysis
```

## Step 2: Your First Analysis

Let's create some test data to analyze:

```sql
-- Create a problematic table (no primary key)
CREATE TABLE users (
    id INTEGER,
    username TEXT,
    email TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create another table with issues
CREATE TABLE orders (
    order_id SERIAL,
    user_id INTEGER,
    total DECIMAL(10,2),
    -- Missing primary key constraint
    -- Missing foreign key to users table
    -- Missing index on user_id
);

-- Insert some test data
INSERT INTO users VALUES
    (1, 'alice', 'alice@example.com', NOW()),
    (2, 'bob', 'bob@example.com', NOW());

INSERT INTO orders VALUES
    (1, 1, 99.99),
    (2, 1, 149.50),
    (3, 2, 75.25);
```

Now run your first analysis:

```sql
-- Run basic database analysis
SELECT * FROM pg_linter.perform_base_check();
```

You should see results like:
```
 ruleid | level   | message                                                    | count
--------+---------+------------------------------------------------------------+-------
 B001   | warning | 2 tables without primary key exceed the warning threshold: 10% | 2
```

## Step 3: Understanding Results

### Result Columns

- **ruleid**: The rule identifier (B001, B002, etc.)
- **level**: Severity level (error, warning, info)
- **message**: Description of the issue found
- **count**: Number of occurrences (optional)

### Rule Categories

DBLinter organizes rules into categories:

- **B-series**: Database-wide base rules
- **T-series**: Individual table rules
- **C-series**: Cluster configuration rules
- **S-series**: Schema-level rules

### Get Rule Details

```sql
-- Get detailed explanation of a rule
SELECT pg_linter.explain_rule('B001');
```

Output:
```
Rule B001: Tables without primary keys

Description: Detects tables that don't have a primary key defined

How to fix:
1. Add a primary key constraint to each table
2. Use SERIAL or BIGSERIAL for auto-incrementing keys
3. Consider composite primary keys for junction tables
4. Ensure all tables have a unique identifier
```

## Step 4: Fix the Issues

Let's fix the problems we found:

```sql
-- Fix the users table
ALTER TABLE users ADD CONSTRAINT users_pkey PRIMARY KEY (id);

-- Fix the orders table
ALTER TABLE orders ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);

-- Add proper foreign key relationship
ALTER TABLE orders ADD CONSTRAINT orders_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id);

-- Add index for foreign key performance
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

Now run the analysis again:

```sql
SELECT * FROM pg_linter.perform_base_check();
```

You should see no issues, or significantly fewer issues!

## Step 5: Save Results to File

For CI/CD or reporting, save results to a SARIF file:

```sql
-- Save to file
SELECT pg_linter.perform_base_check('/tmp/my_database_analysis.sarif');
```

Check the file:

```bash
cat /tmp/my_database_analysis.sarif
```

You'll see JSON output in SARIF format, which can be consumed by various tools.

## Step 6: Rule Management

### View All Rules

```sql
-- See all available rules
SELECT * FROM pg_linter.show_rules();
```

### Enable/Disable Rules

```sql
-- Disable a rule you don't need
SELECT pg_linter.disable_rule('B006'); -- Uppercase names

-- Check if a rule is enabled
SELECT pg_linter.is_rule_enabled('B006');

-- Re-enable it
SELECT pg_linter.enable_rule('B006');
```

### Run Specific Analysis Types

```sql
-- Run only table-specific analysis
SELECT * FROM pg_linter.perform_table_check();

-- Run cluster configuration analysis
SELECT * FROM pg_linter.perform_cluster_check();

-- Run schema analysis
SELECT * FROM pg_linter.perform_schema_check();
```

## Step 7: Real-World Scenarios

### Scenario 1: Pre-deployment Check

```sql
-- Configure strict rules for production
SELECT pg_linter.enable_rule(rule_code)
FROM pg_linter.show_rules()
WHERE rule_code IN ('B001', 'B002', 'B003', 'T004', 'T008');

-- Run comprehensive check
SELECT pg_linter.perform_base_check('/tmp/pre_deploy_check.sarif');
SELECT pg_linter.perform_table_check('/tmp/pre_deploy_tables.sarif');
```

### Scenario 2: Performance Analysis

```sql
-- Focus on performance-related rules
SELECT pg_linter.disable_rule(rule_code)
FROM pg_linter.show_rules()
WHERE rule_code NOT IN ('B002', 'B004', 'T003', 'T005', 'T007');

-- Run performance-focused analysis
SELECT * FROM pg_linter.perform_base_check();
SELECT * FROM pg_linter.perform_table_check();
```

### Scenario 3: Security Audit

```sql
-- Enable security-focused rules
SELECT pg_linter.enable_rule('B005'); -- Public schema security
SELECT pg_linter.enable_rule('C002'); -- pg_hba security
SELECT pg_linter.enable_rule('T009'); -- Role grants

-- Run security analysis
SELECT * FROM pg_linter.perform_base_check();
SELECT * FROM pg_linter.perform_cluster_check();
```

## Step 8: Integration Examples

### Simple CI/CD Integration

Create a script `check_db.sh`:

```bash
#!/bin/bash
set -e

DB_NAME="${1:-myapp_db}"
RESULTS_FILE="/tmp/dblinter_results_$(date +%Y%m%d_%H%M%S).sarif"

echo "Running DBLinter analysis on $DB_NAME..."

# Run analysis
psql -d "$DB_NAME" -c "SELECT pg_linter.perform_base_check('$RESULTS_FILE');"

# Check for critical issues
if grep -q '"level": "error"' "$RESULTS_FILE"; then
    echo "❌ CRITICAL ISSUES FOUND!"
    grep -A 3 '"level": "error"' "$RESULTS_FILE"
    exit 1
else
    echo "✅ No critical issues found"
fi

# Check for warnings
WARNING_COUNT=$(grep -c '"level": "warning"' "$RESULTS_FILE" || echo "0")
echo "Found $WARNING_COUNT warnings"

echo "Analysis complete. Results saved to: $RESULTS_FILE"
```

Use it in your pipeline:

```bash
# Make executable
chmod +x check_db.sh

# Run the check
./check_db.sh production_db
```

### Monitoring Integration

Create a monitoring script `monitor_db.sh`:

```bash
#!/bin/bash
# Daily database health check

DB_NAME="production_db"
LOG_DIR="/var/log/dblinter"
DATE=$(date +%Y-%m-%d)

mkdir -p "$LOG_DIR"

# Run analysis
psql -d "$DB_NAME" -c "
SELECT pg_linter.perform_base_check('$LOG_DIR/base_$DATE.sarif');
SELECT pg_linter.perform_table_check('$LOG_DIR/tables_$DATE.sarif');
"

# Count issues
ERRORS=$(grep -c '"level": "error"' "$LOG_DIR"/*_$DATE.sarif 2>/dev/null || echo "0")
WARNINGS=$(grep -c '"level": "warning"' "$LOG_DIR"/*_$DATE.sarif 2>/dev/null || echo "0")

echo "Database analysis complete for $DATE"
echo "Errors: $ERRORS, Warnings: $WARNINGS"

# Alert if critical issues
if [ "$ERRORS" -gt 0 ]; then
    echo "ALERT: Critical database issues found!" | mail -s "DB Alert" admin@company.com
fi
```

## Step 9: Best Practices

### Development Environment

- Enable core rules: B001 (primary keys), T004 (FK indexing)
- Disable strict rules: B005 (public schema), T010 (reserved keywords)
- Run analysis after schema changes

### Testing Environment

- Enable all data integrity rules
- Focus on constraint validation
- Test fixes before production deployment

### Production Environment

- Enable all rules for comprehensive monitoring
- Schedule regular analysis (daily/weekly)
- Set up alerting for critical issues
- Maintain historical analysis results

## Troubleshooting

### Common Issues

**Permission denied:**
```sql
-- Grant necessary permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dblinter TO your_user;
```

**No results returned:**
```sql
-- Check if rules are enabled
SELECT * FROM pg_linter.show_rules() WHERE enabled = true;

-- Verify you have tables to analyze
SELECT count(*) FROM pg_tables WHERE schemaname = 'public';
```

**File writing errors:**
```bash
# Ensure PostgreSQL can write to the directory
sudo chown postgres:postgres /tmp/
sudo chmod 755 /tmp/
```

### Getting Help

- Check the [Functions Reference](../functions/README.md) for detailed function documentation
- Review [How-To Guides](../how-to/README.md) for specific scenarios
- See [Configuration Guide](../configure.md) for advanced setup

## Next Steps

Now that you're familiar with the basics:

1. **Explore Advanced Features**: Learn about [rule configuration](../configure.md)
2. **Set Up Automation**: Implement [CI/CD integration](../how-to/README.md#setting-up-dblinter-in-cicd)
3. **Monitor Your Database**: Set up [regular monitoring](../how-to/README.md#integrating-with-monitoring-systems)
4. **Learn All Rules**: Review the complete [rule reference](../rules/)

## Clean Up

Remove the test data:

```sql
-- Clean up test tables
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS users CASCADE;
```

Congratulations! You've completed the DBLinter quick start tutorial. You now know how to install, configure, and use DBLinter to improve your database quality and performance.
