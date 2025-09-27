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

## Rule Configuration Management with YAML

### Exporting Rules to YAML

pglinter supports exporting rule configurations to YAML format for backup, version control, or modification:

```sql
-- Export all rules to YAML string (view in psql output)
SELECT pglinter.export_rules_to_yaml();

-- Export rules directly to a file
SELECT pglinter.export_rules_to_file('/tmp/pglinter_rules_backup.yaml');
```

### Sample YAML Output

The exported YAML includes metadata and all rule configurations:

```yaml
metadata:
  export_timestamp: "2024-01-15T14:30:00Z"
  total_rules: 45
  format_version: "1.0"
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
    q1: "SELECT count(*) FROM pg_tables WHERE schemaname NOT IN ('information_schema', 'pg_catalog')"
    q2: "SELECT count(*) FROM pg_tables t WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = t.oid AND contype = 'p') AND t.schemaname NOT IN ('information_schema', 'pg_catalog')"
  - id: 2
    name: "HowManyRedudantIndex"
    code: "B002"
    enable: true
    warning_level: 20
    error_level: 80
    scope: "BASE"
    # ... more rules
```

### Modifying Rules in YAML

Common modifications you can make to the YAML file:

1. **Adjust Warning/Error Thresholds**:
   ```yaml
   # Make B001 more sensitive (lower thresholds)
   - id: 1
     name: "HowManyTableWithoutPrimaryKey" 
     code: "B001"
     warning_level: 10  # Changed from 20
     error_level: 50    # Changed from 80
   ```

2. **Enable/Disable Rules**:
   ```yaml
   # Disable strict security rules for development
   - id: 5
     code: "B005"
     enable: false      # Changed from true
   ```

3. **Customize Messages**:
   ```yaml
   # Add more descriptive message
   - id: 1
     code: "B001"
     message: "⚠️ DATABASE HEALTH: {0}/{1} tables lack primary keys ({3}% exceeds {2}% threshold). This impacts data integrity and replication."
   ```

4. **Update Rule Queries**:
   ```yaml
   # Modify B001 to exclude specific schemas
   - id: 1
     code: "B001" 
     q1: "SELECT count(*) FROM pg_tables WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'staging', 'temp')"
     q2: "SELECT count(*) FROM pg_tables t WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = t.oid AND contype = 'p') AND t.schemaname NOT IN ('information_schema', 'pg_catalog', 'staging', 'temp')"
   ```

### Re-importing Modified Rules

After editing the YAML file, import the changes back:

```sql
-- Import from YAML file
SELECT pglinter.import_rules_from_file('/tmp/pglinter_rules_modified.yaml');

-- Or import directly from YAML string
SELECT pglinter.import_rules_from_yaml('
metadata:
  format_version: "1.0"
rules:
  - id: 1
    code: "B001"
    warning_level: 10
    error_level: 50
    # ... rest of rule definition
');
```

### Complete Workflow Example

Here's a complete example of exporting, modifying, and re-importing rules:

```bash
#!/bin/bash
# rule_management_workflow.sh

# Step 1: Export current rules
echo "📤 Exporting current rules..."
psql -d myapp_prod -t -c "SELECT pglinter.export_rules_to_file('/tmp/rules_backup.yaml');"

# Step 2: Create a development-friendly version
echo "✏️ Creating development configuration..."
cat > /tmp/rules_dev.yaml << 'EOF'
metadata:
  export_timestamp: "2024-01-15T15:00:00Z"
  total_rules: 3
  format_version: "1.0"
rules:
  # Relaxed primary key rule for development
  - id: 1
    name: "HowManyTableWithoutPrimaryKey"
    code: "B001"
    enable: true
    warning_level: 50    # More lenient for dev
    error_level: 90      # Higher error threshold
    scope: "BASE"
    description: "Count number of tables without primary key (dev settings)."
    message: "DEV: {0}/{1} tables without primary keys ({3}% > {2}%). Consider adding PKs before production."
    fixes: ["Add primary key: ALTER TABLE table_name ADD PRIMARY KEY (id)"]
    q1: "SELECT count(*) FROM pg_tables WHERE schemaname NOT IN ('information_schema', 'pg_catalog')"
    q2: "SELECT count(*) FROM pg_tables t WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = t.oid AND contype = 'p') AND t.schemaname NOT IN ('information_schema', 'pg_catalog')"
    
  # Disable public schema security in dev
  - id: 5
    name: "UnsecuredPublicSchema"
    code: "B005"
    enable: false        # Disabled for development
    warning_level: 20
    error_level: 80
    scope: "BASE"
    description: "Public schema security (disabled in dev)."
    message: "Public schema allows object creation by all users."
    fixes: ["REVOKE CREATE ON SCHEMA public FROM PUBLIC"]
    
  # Keep FK indexing rule active
  - id: 3
    name: "HowManyTableWithoutIndexOnFk"
    code: "B003"
    enable: true
    warning_level: 30    # Slightly more lenient
    error_level: 70
    scope: "BASE"
    description: "Count tables without indexes on foreign keys."
    message: "{0}/{1} tables lack FK indexes ({3}% > {2}%). Performance may suffer."
    fixes: ["CREATE INDEX ON table_name (foreign_key_column)"]
EOF

# Step 3: Apply development configuration
echo "🔧 Applying development configuration..."
psql -d myapp_dev -c "SELECT pglinter.import_rules_from_file('/tmp/rules_dev.yaml');"

# Step 4: Verify changes
echo "✅ Verifying rule changes..."
psql -d myapp_dev -c "
SELECT rule_code, enabled, warning_level, error_level, 
       CASE WHEN enabled THEN '✅' ELSE '❌' END as status
FROM pglinter.show_rules() 
WHERE rule_code IN ('B001', 'B005', 'B003')
ORDER BY rule_code;
"

# Step 5: Run analysis with new settings
echo "🔍 Running analysis with new configuration..."
psql -d myapp_dev -c "SELECT pglinter.perform_base_check();"

echo "🎉 Configuration update complete!"
```

### Environment-Specific Rule Management

Create different YAML configurations for different environments:

```bash
# Create environment-specific configurations
mkdir -p /etc/pglinter/environments

# Production: All rules enabled, strict thresholds
cat > /etc/pglinter/environments/production.yaml << 'EOF'
metadata:
  format_version: "1.0"
rules:
  - {code: "B001", enable: true, warning_level: 5, error_level: 15}
  - {code: "B002", enable: true, warning_level: 10, error_level: 25}
  - {code: "B003", enable: true, warning_level: 10, error_level: 30}
  - {code: "B005", enable: true, warning_level: 0, error_level: 1}
EOF

# Development: Relaxed rules  
cat > /etc/pglinter/environments/development.yaml << 'EOF'
metadata:
  format_version: "1.0"
rules:
  - {code: "B001", enable: true, warning_level: 40, error_level: 80}
  - {code: "B002", enable: true, warning_level: 30, error_level: 60}
  - {code: "B003", enable: true, warning_level: 30, error_level: 70}
  - {code: "B005", enable: false}
EOF

# Apply environment-specific configuration
ENVIRONMENT=${1:-development}
psql -d $DATABASE -c "SELECT pglinter.import_rules_from_file('/etc/pglinter/environments/${ENVIRONMENT}.yaml');"
```

### Version Control Integration

Track rule changes in Git:

```bash
# Add to your deployment pipeline
git add /etc/pglinter/
git commit -m "Update pglinter rules for production deployment"

# Automated rule deployment
#!/bin/bash
# deploy_rules.sh
ENVIRONMENT=$1
RULES_FILE="/etc/pglinter/environments/${ENVIRONMENT}.yaml"

if [[ -f "$RULES_FILE" ]]; then
    echo "Deploying $ENVIRONMENT rules..."
    psql -d $DATABASE -c "SELECT pglinter.import_rules_from_file('$RULES_FILE');"
    echo "✅ Rules deployed successfully"
else
    echo "❌ Rules file not found: $RULES_FILE"
    exit 1
fi
```

This YAML-based approach provides powerful configuration management capabilities, allowing you to maintain consistent rule settings across environments while tracking changes over time.

## Example base on rule B001 and T001 (primary key missing), why using a base and table approach

This example explain the point of view about the B001 rule which detects database-wide primary key issues vs T001 rule.

Key Points about B001:

1. B001 is a BASE-level rule (database-wide analysis)
2. Uses percentage threshold (default: 20%)
3. Triggers when >20% of tables lack primary keys
4. Part of perform_base_check() function
5. Focuses on overall database health metrics

Key Differences B001 vs T001:

- B001: "X tables without primary key exceed the warning threshold: 20%"
- T001: "Found X tables without primary key: schema.table1, schema.table2..."

- B001: Database-wide percentage analysis
- T001: Individual table identification

- B001: Part of base checks (perform_base_check)
- T001: Part of table checks (perform_table_check)

- B001: Useful for monitoring overall database design quality
- T001: Useful for identifying specific tables that need primary keys

Why Both Rules Matter:

- B001 helps DBAs understand overall database design quality
- T001 helps developers know exactly which tables to fix
- Together they provide comprehensive primary key analysis

The B001 rule is particularly useful for:

- Database health monitoring
- Migration planning
- Design quality assessments
- Setting up alerts for design degradation
