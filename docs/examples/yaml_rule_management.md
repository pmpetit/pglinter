# YAML Rule Management Examples

This guide provides step-by-step examples of using pglinter's YAML export/import functionality to manage rule configurations.

## Rule Structure with Embedded Queries

Starting with pglinter 0.0.17, each rule includes its own SQL queries (`q1` and `q2`) that define how the rule analyzes your database:

- **q1**: The primary analysis query that identifies issues or counts problems
- **q2**: Optional secondary query for additional validation or threshold calculations

This means rules are completely self-contained and can be easily exported, modified, and shared between environments.

## Quick Start Example

### 1. Export Current Rules

```sql
-- Export all rules to see current configuration
SELECT pglinter.export_rules_to_yaml();

-- Save to file for editing
SELECT pglinter.export_rules_to_file('/tmp/my_rules.yaml');
```

### 2. Edit the YAML File

```bash
# Open the exported file in your editor
nano /tmp/my_rules.yaml
```

Make your modifications (examples below), then save the file.

### 3. Import Modified Rules

```sql
-- Apply your changes
SELECT pglinter.import_rules_from_file('/tmp/my_rules.yaml');

-- Verify the changes were applied
SELECT rule_code, enabled, warning_level, error_level
FROM pglinter.show_rules()
WHERE rule_code IN ('B001', 'B003', 'B005')
ORDER BY rule_code;
```

## Common Modification Examples

### Example 1: Relaxed Development Settings

Original exported YAML snippet:
```yaml
rules:
  - id: 1
    name: "HowManyTableWithoutPrimaryKey"
    code: "B001"
    enable: true
    warning_level: 20
    error_level: 80
    scope: "BASE"
    description: "Count number of tables without primary key."
    message: "{0}/{1} table(s) without primary key exceed the {2} threshold: {3}%."
    fixes: ["create a primary key or change warning/error threshold"]
    q1: "SELECT COUNT(*) FROM b001_tables_with_pk WHERE has_pk = false"
    q2: "SELECT COUNT(*) FROM b001_total_tables"
```

Modified for development (more lenient):
```yaml
rules:
  - id: 1
    name: "HowManyTableWithoutPrimaryKey"
    code: "B001"
    enable: true
    warning_level: 50    # Increased from 20
    error_level: 90      # Increased from 80
    scope: "BASE"
    description: "Count number of tables without primary key (dev mode)."
    message: "DEV: {0}/{1} table(s) without primary key exceed the {2} threshold: {3}%. Consider adding before production."
    fixes: ["create a primary key or change warning/error threshold"]
    q1: "SELECT COUNT(*) FROM b001_tables_with_pk WHERE has_pk = false"  # Same queries as original
    q2: "SELECT COUNT(*) FROM b001_total_tables"
```

### Example 2: Disable Security Rules for Testing

Find and modify security-related rules:
```yaml
rules:
  - id: 5
    name: "UnsecuredPublicSchema"
    code: "B005"
    enable: false        # Changed from true
    warning_level: 20
    error_level: 80
    scope: "BASE"
    description: "Only authorized users should be allowed to create objects."
    message: "{0}/{1} schemas are unsecured, schemas where all users can create objects in, exceed the {2} threshold: {3}%."
    fixes: ["REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC"]
    q1: "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast') AND has_schema_privilege('public', schema_name, 'CREATE')"
    q2: "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')"
```

### Example 3: Custom Thresholds for Large Databases

For large databases, you might want more strict thresholds:
```yaml
rules:
  - id: 3
    name: "HowManyTableWithoutIndexOnFk"
    code: "B003"
    enable: true
    warning_level: 5     # Very strict - any FK without index triggers warning
    error_level: 15      # Error if >15% of tables have unindexed FKs
    scope: "BASE"
    description: "Count number of tables without index on foreign key."
    message: "CRITICAL: {0}/{1} table(s) without index on foreign key exceed the {2} threshold: {3}%."
    fixes: ["create a index on foreign key or change warning/error threshold"]
    q1: "SELECT COUNT(DISTINCT schemaname||'.'||tablename) FROM b003 WHERE has_index = false"
    q2: "SELECT COUNT(DISTINCT schemaname||'.'||tablename) FROM b003"
```

## Complete Workflow Examples

### Workflow 1: Environment-Specific Configurations

**Step 1: Create Base Configuration**
```sql
-- Export production rules as baseline
\o /tmp/prod_rules.yaml
SELECT pglinter.export_rules_to_yaml();
\o
```

**Step 2: Create Development Version**
```bash
# Copy production rules
cp /tmp/prod_rules.yaml /tmp/dev_rules.yaml

# Edit development rules (increase thresholds, disable strict rules)
sed -i 's/warning_level: 20/warning_level: 40/g' /tmp/dev_rules.yaml
sed -i 's/error_level: 80/error_level: 90/g' /tmp/dev_rules.yaml
sed -i '/code: "B005"/,/enable: true/ s/enable: true/enable: false/' /tmp/dev_rules.yaml
```

**Step 3: Apply to Development Database**
```sql
\c myapp_development
SELECT pglinter.import_rules_from_file('/tmp/dev_rules.yaml');

-- Test the configuration
SELECT pglinter.perform_base_check();
```

### Workflow 2: Batch Rule Updates

**Step 1: Export and Modify Multiple Rules**
```sql
SELECT pglinter.export_rules_to_file('/tmp/batch_update.yaml');
```

**Step 2: Script Multiple Changes**
```bash
#!/bin/bash
# batch_rule_update.sh

YAML_FILE="/tmp/batch_update.yaml"

# Make B-series rules more lenient
sed -i '/code: "B[0-9]*"/,/error_level:/ s/warning_level: [0-9]*/warning_level: 30/' "$YAML_FILE"
sed -i '/code: "B[0-9]*"/,/error_level:/ s/error_level: [0-9]*/error_level: 70/' "$YAML_FILE"

# Disable all T010 (sensitive column) rules for development
sed -i '/code: "T010"/,/enable: true/ s/enable: true/enable: false/' "$YAML_FILE"

# Add custom message prefix for all rules
sed -i 's/message: "/message: "[DEV] /' "$YAML_FILE"

echo "Batch modifications applied to $YAML_FILE"
```

**Step 3: Apply Changes**
```sql
SELECT pglinter.import_rules_from_file('/tmp/batch_update.yaml');
```

### Workflow 3: Rule Versioning and Rollback

**Step 1: Version Control Setup**
```bash
mkdir -p /etc/pglinter/versions
cd /etc/pglinter/versions

# Export current state as v1.0
psql -d myapp -t -c "SELECT pglinter.export_rules_to_file('/etc/pglinter/versions/v1.0.yaml');"
git add v1.0.yaml
git commit -m "Initial rule configuration v1.0"
```

**Step 2: Create New Version**
```bash
# Make changes and save as new version
cp v1.0.yaml v1.1.yaml
# ... edit v1.1.yaml ...

git add v1.1.yaml
git commit -m "Updated rule configuration v1.1 - relaxed B001 thresholds"
```

**Step 3: Deploy and Rollback if Needed**
```sql
-- Deploy v1.1
SELECT pglinter.import_rules_from_file('/etc/pglinter/versions/v1.1.yaml');

-- If issues found, rollback to v1.0
SELECT pglinter.import_rules_from_file('/etc/pglinter/versions/v1.0.yaml');
```

## Understanding and Modifying Rule Queries

### Query Structure (q1 and q2)

Each rule contains SQL queries that define its analysis logic:

- **q1 (Primary Query)**: Returns the count or data that triggers the rule
- **q2 (Secondary Query)**: Usually returns the total count for percentage calculations
- **null values**: When q2 is null, the rule uses q1 results directly without percentage calculations

### Example: Modifying Query Logic

You can customize how rules analyze your database by modifying their queries:

```yaml
rules:
  - id: 1
    code: "B001"
    name: "Custom Primary Key Check"
    # Original q1: Check all tables without primary keys
    q1: "SELECT COUNT(*) FROM b001_tables_with_pk WHERE has_pk = false"
    # Original q2: Count total tables
    q2: "SELECT COUNT(*) FROM b001_total_tables"

    # Modified to exclude specific schemas:
    q1: "SELECT COUNT(*) FROM b001_tables_with_pk WHERE has_pk = false AND schemaname NOT IN ('temp', 'staging')"
    q2: "SELECT COUNT(*) FROM b001_total_tables WHERE schemaname NOT IN ('temp', 'staging')"
```

### Common Query Modifications

**1. Exclude Specific Schemas:**
```yaml
# Modify any rule to ignore certain schemas
q1: "SELECT COUNT(*) FROM your_analysis_view WHERE schemaname NOT IN ('temp', 'test', 'backup')"
```

**2. Filter by Table Patterns:**
```yaml
# Only analyze tables matching certain patterns
q1: "SELECT COUNT(*) FROM your_analysis WHERE tablename LIKE 'app_%' OR tablename LIKE 'user_%'"
```

**3. Add Time-Based Filtering:**
```yaml
# Only check recently modified tables
q1: "SELECT COUNT(*) FROM your_analysis a JOIN pg_stat_user_tables s ON a.schemaname = s.schemaname AND a.tablename = s.relname WHERE s.last_autoanalyze > NOW() - INTERVAL '7 days'"
```

**4. Custom Thresholds in Queries:**
```yaml
# Build thresholds directly into the query
q1: "SELECT COUNT(*) FROM pg_stat_user_tables WHERE seq_scan > 1000 AND idx_scan < 100"  # Tables with poor index usage
q2: "SELECT COUNT(*) FROM pg_stat_user_tables"
```

## Advanced YAML Techniques

### Custom Rule Creation via YAML

You can create entirely new rules via YAML import:

```yaml
metadata:
  format_version: "1.0"
  total_rules: 1
rules:
  - id: 9999
    name: "CustomTableSizeCheck"
    code: "CUSTOM001"
    enable: true
    warning_level: 100
    error_level: 500
    scope: "TABLE"
    description: "Check for tables larger than specified MB"
    message: "Table {0} is {1}MB, exceeding {2}MB threshold"
    fixes: ["Consider partitioning", "Archive old data", "Add proper indexes"]
    q1: "SELECT schemaname||'.'||tablename, pg_total_relation_size(schemaname||'.'||tablename)/1024/1024 as size_mb FROM pg_tables WHERE pg_total_relation_size(schemaname||'.'||tablename)/1024/1024 > 100"
    q2: null
```

### Conditional Rule Configuration

Use different YAML files for different scenarios:

```bash
# /etc/pglinter/scenarios/migration.yaml - During migrations
rules:
  - {code: "B001", enable: false}  # Disable PK checks during migration
  - {code: "B003", warning_level: 80, error_level: 95}  # Relax FK index rules

# /etc/pglinter/scenarios/production.yaml - Production monitoring
rules:
  - {code: "B001", enable: true, warning_level: 5, error_level: 10}
  - {code: "B003", enable: true, warning_level: 10, error_level: 25}

# Apply based on context
case "$DEPLOYMENT_PHASE" in
  "migration")
    psql -c "SELECT pglinter.import_rules_from_file('/etc/pglinter/scenarios/migration.yaml');"
    ;;
  "production")
    psql -c "SELECT pglinter.import_rules_from_file('/etc/pglinter/scenarios/production.yaml');"
    ;;
esac
```

## Troubleshooting

### Common Issues

1. **Invalid YAML Format**
   ```sql
   -- This will show parsing errors
   SELECT pglinter.import_rules_from_yaml('invalid: yaml: content:');
   ```

2. **Missing Required Fields**
   ```yaml
   # This will fail - missing required fields
   rules:
     - code: "B001"
       # Missing: id, name, enable, etc.
   ```

3. **Rule ID Conflicts**
   ```yaml
   # Ensure IDs match existing rules for updates
   # or use new IDs for new rules
   - id: 1      # Updates existing rule with ID 1
   - id: 9999   # Creates new rule with ID 9999
   ```

### Validation

Always verify your changes after import:

```sql
-- Check specific rules were updated
SELECT rule_code, enabled, warning_level, error_level,
       LEFT(message, 50) || '...' as message_preview
FROM pglinter.show_rules()
WHERE rule_code IN ('B001', 'B003', 'B005');

-- Test rule execution
SELECT pglinter.explain_rule('B001');

-- Run analysis to see changes in action
SELECT pglinter.perform_base_check();
```

This YAML-based configuration management provides a powerful way to maintain consistent database linting standards across different environments and development phases.
