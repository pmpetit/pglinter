# pglinter Examples

Practical examples of using pglinter in real-world scenarios.

## Basic Usage Examples

### Simple Database Analysis

```sql
-- Quick health check
SELECT * FROM pglinter.perform_base_check();

-- Save results to file
SELECT pglinter.perform_base_check('/tmp/db_analysis.sarif');

-- Check specific rule
SELECT pglinter.explain_rule('B001');
```

### Rule Management

```sql
-- View all rules
SELECT rule_code, enabled, description
FROM pglinter.show_rules()
ORDER BY rule_code;

-- Enable/disable rules
SELECT pglinter.disable_rule('B005'); -- Public schema security
SELECT pglinter.enable_rule('T004');  -- FK indexing

-- Check rule status
SELECT pglinter.is_rule_enabled('B002');
```

## Configuration Examples

### Development Environment Setup

```sql
-- config/development.sql
\echo 'Configuring pglinter for development environment...'

-- Disable strict rules for development
SELECT pglinter.disable_rule('B005'); -- Public schema
SELECT pglinter.disable_rule('C002'); -- pg_hba security
SELECT pglinter.disable_rule('T009'); -- Role grants
SELECT pglinter.disable_rule('T010'); -- Reserved keywords

-- Enable core data integrity rules
SELECT pglinter.enable_rule('B001');  -- Primary keys
SELECT pglinter.enable_rule('T001');  -- Table primary keys
SELECT pglinter.enable_rule('T004');  -- FK indexing
SELECT pglinter.enable_rule('T008');  -- FK type mismatches

\echo 'Development configuration complete.'
```

### Production Environment Setup

```sql
-- config/production.sql
\echo 'Configuring pglinter for production environment...'

-- Enable all security and performance rules
SELECT pglinter.enable_rule(rule_code)
FROM pglinter.show_rules();

\echo 'Production configuration complete.'
```

### Performance-Focused Configuration

```sql
-- config/performance.sql
\echo 'Configuring pglinter for performance analysis...'

-- Disable non-performance rules
SELECT pglinter.disable_rule(rule_code)
FROM pglinter.show_rules()
WHERE rule_code NOT IN (
    'B002', -- Redundant indexes
    'B004', -- Unused indexes
    'T003', -- Table redundant indexes
    'T005', -- High sequential scans
    'T007'  -- Table unused indexes
);

\echo 'Performance configuration complete.'
```

### Rule Level Configuration

For advanced rule customization, see the [Rule Level Management Examples](rule_level_management.md) which covers:

- **Configurable Thresholds**: Adjust warning/error levels for rules like T005
- **Environment-Specific Settings**: Different thresholds for dev/staging/production
- **Bulk Rule Management**: Enable/disable all rules at once
- **Monitoring Integration**: Track configuration changes and effectiveness

```sql
-- Quick example: Adjust T005 sequential scan thresholds
SELECT pglinter.update_rule_levels('T005', 30.0, 70.0);  -- More sensitive
SELECT pglinter.enable_all_rules();                      -- Enable everything
```

## Scripted Analysis Examples

### Multi-Database Analysis

```bash
#!/bin/bash
# analyze_all_databases.sh - Analyze multiple databases

DATABASES=("app_prod" "app_staging" "analytics" "reporting")
ANALYSIS_DATE=$(date +%Y-%m-%d_%H-%M)
REPORT_DIR="/var/log/pglinter/multi-db-$ANALYSIS_DATE"

mkdir -p "$REPORT_DIR"

for db in "${DATABASES[@]}"; do
    echo "Analyzing database: $db"

    # Create database-specific directory
    mkdir -p "$REPORT_DIR/$db"

    # Run analysis
    psql -d "$db" -c "
    -- Configure based on database type
    $(case $db in
        *prod*) echo 'SELECT pglinter.enable_rule(rule_code) FROM pglinter.show_rules();' ;;
        *staging*) echo 'SELECT pglinter.disable_rule(''T010''); SELECT pglinter.disable_rule(''C002'');' ;;
        *analytics*) echo 'SELECT pglinter.disable_rule(''B001''); SELECT pglinter.disable_rule(''T001'');' ;;
    esac)

    SELECT pglinter.perform_base_check('$REPORT_DIR/$db/base.sarif');
    SELECT pglinter.perform_table_check('$REPORT_DIR/$db/tables.sarif');
    "

    echo "✅ Completed analysis for $db"
done

# Generate summary report
echo "Generating summary report..."

{
    echo "# Multi-Database Analysis Report"
    echo "Generated: $(date)"
    echo ""

    for db in "${DATABASES[@]}"; do
        echo "## Database: $db"

        errors=$(grep -c '"level": "error"' "$REPORT_DIR/$db"/*.sarif 2>/dev/null || echo "0")
        warnings=$(grep -c '"level": "warning"' "$REPORT_DIR/$db"/*.sarif 2>/dev/null || echo "0")

        echo "- Errors: $errors"
        echo "- Warnings: $warnings"
        echo ""
    done
} > "$REPORT_DIR/summary.md"

echo "📊 Summary report created: $REPORT_DIR/summary.md"
```
