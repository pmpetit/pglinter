# Functions Reference

Complete reference for all PG Linter functions and their usage.

## Core Functions

### perform_base_check([output_file])

Executes all enabled base rules (B-series) and returns or saves results.

## Syntax: perform_base_check

```sql
SELECT pglinter.perform_base_check([output_file text]);
```

## Parameters

- `output_file` (optional): Path to save SARIF results. If omitted, results are returned to console.

## Returns

- When `output_file` specified: Success message
- When no file specified: Table with rule results

## Examples

```sql
-- Output to console
SELECT * FROM pglinter.perform_base_check();

-- Save to file
SELECT pglinter.perform_base_check('/tmp/base_results.sarif');

-- Dynamic filename
SELECT pglinter.perform_base_check(
    '/logs/base_' || to_char(now(), 'YYYY-MM-DD') || '.sarif'
);
```

## Rule Coverage

- B001: Tables without primary keys
- B002: Redundant indexes
- B003: Tables without indexes on foreign keys
- B004: Unused indexes
- B005: Unsecured public schema
- B006: Objects with uppercase names
- B007: Tables never selected
- B008: Tables with foreign keys outside their schema

---

### perform_cluster_check([output_file])

Executes all enabled cluster rules (C-series) for PostgreSQL configuration analysis.

## Syntax

```sql
SELECT pglinter.perform_cluster_check([output_file text]);
```

## Parameters

- `output_file` (optional): Path to save SARIF results

## Returns

- When `output_file` specified: Success message
- When no file specified: Table with rule results

## Examples

```sql
-- Check cluster configuration
SELECT * FROM pglinter.perform_cluster_check();

-- Save cluster analysis
SELECT pglinter.perform_cluster_check('/tmp/cluster_analysis.sarif');
```

## Rule Coverage

- C002: Insecure pg_hba.conf entries

---

### perform_table_check([output_file])

Executes all enabled table rules (T-series) for individual table analysis.

## Syntax

```sql
SELECT pglinter.perform_table_check([output_file text]);
```

## Parameters

- `output_file` (optional): Path to save SARIF results

## Returns

- When `output_file` specified: Success message
- When no file specified: Table with rule results

## Examples

```sql
-- Analyze all tables
SELECT * FROM pglinter.perform_table_check();

-- Save table analysis
SELECT pglinter.perform_table_check('/tmp/table_analysis.sarif');
```

## Rule Coverage

- T001: Table without primary key
- T002: Table with redundant indexes
- T003: Table with foreign keys not indexed
- T004: Table with potential missing indexes
- T005: Table with foreign keys outside schema
- T006: Table with unused indexes
- T007: Table with foreign key type mismatch
- T008: Table with no roles granted
- T009: Reserved keywords in object names
- T010: Table with sensitive columns

---

### perform_schema_check([output_file])

Executes all enabled schema rules (S-series) for schema-level analysis.

## Syntax

```sql
SELECT pglinter.perform_schema_check([output_file text]);
```

## Parameters

- `output_file` (optional): Path to save SARIF results

## Returns

- When `output_file` specified: Success message
- When no file specified: Table with rule results

## Examples

```sql
-- Analyze schemas
SELECT * FROM pglinter.perform_schema_check();

-- Save schema analysis
SELECT pglinter.perform_schema_check('/tmp/schema_analysis.sarif');
```

## Rule Coverage

- S001: Schema with no default role granted

---

## Rule Management Functions

### list_rules()

Displays a formatted list of all available rules with their current status and names.

## Syntax

```sql
SELECT pglinter.list_rules();
```

## Returns

- `text`: Formatted table showing all rules with status icons, codes, status, and names

## Example

```sql
-- Show formatted list of all rules
SELECT pglinter.list_rules();
```

## Sample Output

```text
📋 Available Rules:
============================================================
✅ [B001] ENABLED - Tables without primary keys
❌ [B002] DISABLED - Redundant indexes detection
✅ [B003] ENABLED - Foreign keys without indexes
❌ [T001] DISABLED - Individual table primary key check
✅ [T005] ENABLED - Sequential scan analysis
============================================================
```

## Features

- **Visual Status**: Uses ✅ for enabled rules and ❌ for disabled rules
- **Clear Format**: Shows rule code, status, and descriptive name
- **Complete List**: Displays all available rules in the system
- **Sorted Output**: Rules are ordered by rule code for easy scanning

---

### show_rules()

Displays all available rules with their current status.

## Syntax

```sql
SELECT * FROM pglinter.show_rules();
```

## Returns

Table with columns:
- `rule_code`: Rule identifier (e.g., 'B001')
- `description`: Brief rule description
- `enabled`: Whether rule is currently enabled
- `scope`: Rule category (Base, Cluster, Table, Schema)

## Example

```sql
-- Show all rules
SELECT * FROM pglinter.show_rules();

-- Show only enabled rules
SELECT * FROM pglinter.show_rules() WHERE enabled = true;

-- Show rules by category
SELECT * FROM pglinter.show_rules() WHERE rule_code LIKE 'B%';
```

---

### is_rule_enabled(rule_code)

Checks if a specific rule is currently enabled.

## Syntax

```sql
SELECT pglinter.is_rule_enabled(rule_code text);
```

## Parameters

- `rule_code`: Rule identifier (e.g., 'B001')

## Returns

- `boolean`: true if enabled, false if disabled, NULL if rule doesn't exist

## Examples

```sql
-- Check if B001 is enabled
SELECT pglinter.is_rule_enabled('B001');

-- Check multiple rules
SELECT rule_code, pglinter.is_rule_enabled(rule_code) as enabled
FROM (VALUES ('B001'), ('B002'), ('T001')) AS rules(rule_code);
```

---

### enable_rule(rule_code)

Enables a specific rule for future analysis.

## Syntax

```sql
SELECT pglinter.enable_rule(rule_code text);
```

## Parameters

- `rule_code`: Rule identifier to enable

## Returns

- `text`: Success or error message

## Examples

```sql
-- Enable a specific rule
SELECT pglinter.enable_rule('B001');

-- Enable multiple rules
SELECT pglinter.enable_rule('B001'),
       pglinter.enable_rule('B002'),
       pglinter.enable_rule('T001');

-- Enable all base rules
SELECT pglinter.enable_rule(rule_code)
FROM pglinter.show_rules()
WHERE rule_code LIKE 'B%';
```

---

### disable_rule(rule_code)

Disables a specific rule from future analysis.

## Syntax

```sql
SELECT pglinter.disable_rule(rule_code text);
```

## Parameters

- `rule_code`: Rule identifier to disable

## Returns

- `text`: Success or error message

## Examples

```sql
-- Disable a specific rule
SELECT pglinter.disable_rule('B004');

-- Disable performance-related rules
SELECT pglinter.disable_rule('B004'), -- Unused indexes
       pglinter.disable_rule('T007'), -- Table unused indexes
       pglinter.disable_rule('T005'); -- High seq scans
```

---

### explain_rule(rule_code)

Provides detailed information about a specific rule including description and fixes.

## Syntax

```sql
SELECT pglinter.explain_rule(rule_code text);
```

## Parameters

- `rule_code`: Rule identifier to explain

## Returns

- `text`: Detailed rule explanation with description and numbered fix recommendations

## Examples

```sql
-- Get explanation for B002
SELECT pglinter.explain_rule('B002');

-- Get explanations for all rules
SELECT rule_code, pglinter.explain_rule(rule_code) as explanation
FROM pglinter.show_rules()
ORDER BY rule_code;
```

## Sample Output

```text
Rule B002: Redundant indexes

Description: Detects redundant indexes that have identical column sets

How to fix:
1. Identify redundant indexes using pg_stat_user_indexes
2. Drop unnecessary duplicate indexes
3. Keep the most appropriately named index
4. Consider if indexes serve different purposes (unique vs non-unique)
```

---

### enable_all_rules()

Enables all currently disabled rules in the system.

## Syntax

```sql
SELECT pglinter.enable_all_rules();
```

## Returns

- `text`: Success message with count of rules enabled

## Examples

```sql
-- Enable all disabled rules
SELECT pglinter.enable_all_rules();
-- Returns: "Enabled 5 rules"

-- Check effect
SELECT count(*) as total_rules,
       sum(case when enabled then 1 else 0 end) as enabled_rules
FROM pglinter.show_rules();
```

---

### disable_all_rules()

Disables all currently enabled rules in the system.

## Syntax

```sql
SELECT pglinter.disable_all_rules();
```

## Returns

- `text`: Success message with count of rules disabled

## Examples

```sql
-- Disable all enabled rules
SELECT pglinter.disable_all_rules();
-- Returns: "Disabled 12 rules"

-- Selective re-enable
SELECT pglinter.enable_rule('B001'),  -- Critical rules only
       pglinter.enable_rule('T001');
```

---

### update_rule_levels(rule_code, warning_level, error_level)

Updates the warning and error thresholds for configurable rules.

## Syntax

```sql
SELECT pglinter.update_rule_levels(
    rule_code text,
    warning_level numeric,
    error_level numeric
);
```

## Parameters

- `rule_code`: Rule identifier to update (e.g., 'T005')
- `warning_level`: Warning threshold (NULL to keep current value)
- `error_level`: Error threshold (NULL to keep current value)

## Returns

- `text`: Success message confirming the update

## Examples

```sql
-- Update both levels for T005 (sequential scan rule)
SELECT pglinter.update_rule_levels('T005', 40.0, 80.0);
-- Returns: "Updated rule T005: warning_level=40, error_level=80"

-- Update only warning level
SELECT pglinter.update_rule_levels('T005', 30.0, NULL);
-- Returns: "Updated rule T005: warning_level=30"

-- Update only error level
SELECT pglinter.update_rule_levels('T005', NULL, 95.0);
-- Returns: "Updated rule T005: error_level=95"
```

## Notes

- Only applies to rules with configurable thresholds (currently T005)
- Use NULL to preserve existing values for either parameter
- For T005: values represent percentage thresholds for sequential scan ratio

---

### get_rule_levels(rule_code)

Retrieves the current warning and error threshold levels for a rule.

## Syntax

```sql
SELECT pglinter.get_rule_levels(rule_code text);
```

## Parameters

- `rule_code`: Rule identifier to query

## Returns

- `text`: Current warning and error levels, or default values if rule not configured

## Examples

```sql
-- Get current levels for T005
SELECT pglinter.get_rule_levels('T005');
-- Returns: "Rule T005: warning_level=50, error_level=90"

-- Check levels for all configurable rules
SELECT 'T005' as rule_code, pglinter.get_rule_levels('T005') as levels;
```

## Notes

- Returns default values (warning=50, error=90) for unconfigured rules
- Currently only T005 supports configurable levels
- Values for T005 represent percentage thresholds

---

## Rule Import/Export Functions

### export_rules_to_yaml()

Exports all rules and their configurations to YAML format.

## Syntax

```sql
SELECT pglinter.export_rules_to_yaml();
```

## Returns

- `text`: YAML-formatted string containing all rules with metadata, configuration, and timestamps

## Examples

```sql
-- Export all rules to view YAML structure
SELECT pglinter.export_rules_to_yaml();

-- Save export to a variable for processing
\set yaml_export `SELECT pglinter.export_rules_to_yaml();`
\echo :yaml_export
```

## Sample Output

```yaml
metadata:
  export_timestamp: "2023-10-15T14:30:00Z"
  total_rules: 15
  format_version: "1.0"
rules:
  B001:
    name: "Tables without primary keys"
    enabled: true
    scope: "BASE"
    warning_level: 20
    error_level: 80
    message: "Tables without primary key found"
    # ... additional rule data
```

---

### export_rules_to_file(file_path)

Exports all rules and configurations directly to a YAML file on the filesystem.

## Syntax

```sql
SELECT pglinter.export_rules_to_file(file_path text);
```

## Parameters

- `file_path`: Absolute path where the YAML file will be created

## Returns

- `text`: Success message confirming export completion and file location

## Examples

```sql
-- Export to a specific file
SELECT pglinter.export_rules_to_file('/tmp/pglinter_rules.yaml');

-- Export with timestamp in filename
SELECT pglinter.export_rules_to_file(
    '/backups/rules_' || to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') || '.yaml'
);

-- Export for version control
SELECT pglinter.export_rules_to_file('/project/config/pglinter_rules.yaml');
```

## Notes

- Requires PostgreSQL to have write access to the specified directory
- Creates a complete backup of all rule configurations
- Includes metadata about export time and rule counts
- Can be used for version control of rule configurations

---

### import_rules_from_yaml(yaml_content)

Imports rule configurations from a YAML string, creating new rules or updating existing ones.

## Syntax

```sql
SELECT pglinter.import_rules_from_yaml(yaml_content text);
```

## Parameters

- `yaml_content`: YAML-formatted string containing rule definitions

## Returns

- `text`: Summary of import operation including counts of new and updated rules

## Examples

```sql
-- Import from a YAML string
SELECT pglinter.import_rules_from_yaml('
metadata:
  format_version: "1.0"
rules:
  CUSTOM001:
    name: "Custom validation rule"
    enabled: true
    scope: "TABLE"
    warning_level: 10
    error_level: 50
');

-- Import complex configuration
SELECT pglinter.import_rules_from_yaml('
metadata:
  format_version: "1.0"
rules:
  B001:
    enabled: false
    warning_level: 15
    error_level: 85
  T005:
    enabled: true
    warning_level: 30
    error_level: 70
');
```

---

### import_rules_from_file(file_path)

Imports rule configurations from a YAML file on the filesystem.

## Syntax

```sql
SELECT pglinter.import_rules_from_file(file_path text);
```

## Parameters

- `file_path`: Absolute path to the YAML file containing rule definitions

## Returns

- `text`: Summary of import operation including counts of new and updated rules

## Examples

```sql
-- Import from a configuration file
SELECT pglinter.import_rules_from_file('/config/pglinter_rules.yaml');

-- Import from backup
SELECT pglinter.import_rules_from_file('/backups/rules_2023-10-15.yaml');

-- Import development configuration
SELECT pglinter.import_rules_from_file('/project/dev_rules.yaml');
```

## Error Handling

Common error scenarios and solutions:

```sql
-- File not found
SELECT pglinter.import_rules_from_file('/nonexistent/file.yaml');
-- Returns: "Error: File read error - file not found"

-- Invalid YAML syntax
SELECT pglinter.import_rules_from_yaml('invalid: yaml: content:');
-- Returns: "Error: YAML parsing error - invalid syntax"

-- Permission denied
SELECT pglinter.export_rules_to_file('/root/protected.yaml');
-- Returns: "Error: File write error - permission denied"
```

## Use Cases

### Configuration Management

```sql
-- 1. Export current production configuration
SELECT pglinter.export_rules_to_file('/backups/prod_rules.yaml');

-- 2. Import to development environment
SELECT pglinter.import_rules_from_file('/backups/prod_rules.yaml');
```

### Environment-Specific Rules

```sql
-- Development: Relaxed rules
SELECT pglinter.import_rules_from_yaml('
rules:
  T005:
    warning_level: 80
    error_level: 95
');

-- Production: Strict rules
SELECT pglinter.import_rules_from_yaml('
rules:
  T005:
    warning_level: 30
    error_level: 60
');
```

### Version Control Integration

```sql
-- Export for commit
SELECT pglinter.export_rules_to_file('/project/.pglinter/rules.yaml');

-- Import after deployment
SELECT pglinter.import_rules_from_file('/project/.pglinter/rules.yaml');
```

---

## Configurable Rule Thresholds

Some rules support configurable warning and error thresholds that can be customized based on your environment's needs.

### Supported Configurable Rules

#### T005: Sequential Scan Analysis

Rule T005 analyzes tables for potential missing indexes by calculating the percentage of tuples accessed via sequential scans versus total tuples accessed.

## Default Thresholds

- Warning: 50% (when ≥50% of tuple access is via sequential scans)
- Error: 90% (when ≥90% of tuple access is via sequential scans)

## Threshold Management

```sql
-- Check current T005 thresholds
SELECT pglinter.get_rule_levels('T005');

-- Set more sensitive thresholds
SELECT pglinter.update_rule_levels('T005', 30.0, 70.0);

-- Set more relaxed thresholds for development environment
SELECT pglinter.update_rule_levels('T005', 70.0, 95.0);

-- Reset to defaults
SELECT pglinter.update_rule_levels('T005', 50.0, 90.0);
```

## Understanding T005 Results

```sql
-- Example T005 output
-- "Table 'orders' has high sequential scan ratio: 75.5% (warning threshold: 50%)"
-- This means 75.5% of tuple access on the 'orders' table uses sequential scans
```

### Best Practices for Threshold Configuration

1. **Development Environment**: Use higher thresholds (70%/95%) to reduce noise
2. **Staging Environment**: Use moderate thresholds (40%/80%) for testing
3. **Production Environment**: Use sensitive thresholds (30%/70%) for optimal performance
4. **High-Traffic Systems**: Consider very sensitive thresholds (20%/50%)

### Future Configurable Rules

Additional rules may support configurable thresholds in future versions. Use `get_rule_levels()` to check if a rule supports configuration:

```sql
-- Check if a rule supports configuration
SELECT pglinter.get_rule_levels('B001');
-- Returns default values if not configurable
```

---

## Result Format

### Console Output

When no output file is specified, functions return a table with these columns:

```sql
-- Example result structure
CREATE TYPE rule_result AS (
    ruleid text,        -- Rule identifier (e.g., 'B001')
    level text,         -- 'error', 'warning', or 'info'
    message text,       -- Descriptive message about the issue
    count bigint        -- Number of occurrences (optional)
);
```

### SARIF File Output

When an output file is specified, results are saved in SARIF (Static Analysis Results Interchange Format) JSON:

```json
{
  "$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "pglinter",
          "version": "1.0.0"
        }
      },
      "results": [
        {
          "ruleId": "B001",
          "level": "warning",
          "message": {
            "text": "5 tables without primary key exceed the warning threshold: 10%"
          },
          "properties": {
            "count": 5
          }
        }
      ]
    }
  ]
}
```

## Error Handling

### Common Errors

1. **Permission Denied**

```sql
ERROR: permission denied for function perform_base_check
```

Solution: Ensure user has appropriate privileges

2. **File Write Error**

```sql
ERROR: could not open file "/invalid/path/results.sarif" for writing
```

Solution: Check file path permissions and PostgreSQL file access settings

3. **Invalid Rule Code**

```sql
NOTICE: Rule 'INVALID' not found
```

Solution: Use valid rule codes from `show_rules()`

### Error Response Format

Functions return descriptive error messages:

```sql
-- Invalid rule code
SELECT pglinter.enable_rule('INVALID');
-- Returns: "Rule 'INVALID' not found"

-- File permission error
SELECT pglinter.perform_base_check('/root/protected.sarif');
-- Returns: "Error: could not write to file '/root/protected.sarif'"
```

## Performance Considerations

### Resource Usage

- **Memory**: Rules analyze metadata, not data rows (low memory usage)
- **CPU**: Analysis scales with number of database objects
- **I/O**: File output requires write permissions
- **Locks**: Uses read-only queries (minimal locking)

### Optimization Tips

1. **Selective Analysis**

```sql
-- Run only specific rule categories
SELECT pglinter.perform_table_check(); -- Only table rules
```

1. **Scheduled Analysis**

```sql
-- Run during low-usage periods
SELECT cron.schedule('pglinter-weekly', '0 2 * * 0',
    'SELECT pglinter.perform_base_check(''/logs/weekly.sarif'');');
```

3. **Rule Management**

```sql
-- Disable expensive rules in development
SELECT pglinter.disable_rule('T005'); -- High seq scan analysis
```

## Integration Examples

### CI/CD Pipeline

```yaml
# GitHub Actions example
- name: Database Analysis
  run: |
    psql -c "SELECT pglinter.perform_base_check('/tmp/results.sarif');"

- name: Upload Results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: /tmp/results.sarif
```

### Monitoring Script

```bash
#!/bin/bash
# daily_db_check.sh

DB_NAME="production_db"
OUTPUT_DIR="/var/log/pglinter"
DATE=$(date +%Y-%m-%d)

# Run comprehensive analysis
psql -d $DB_NAME -c "
SELECT pglinter.perform_base_check('$OUTPUT_DIR/base_$DATE.sarif');
SELECT pglinter.perform_table_check('$OUTPUT_DIR/table_$DATE.sarif');
SELECT pglinter.perform_cluster_check('$OUTPUT_DIR/cluster_$DATE.sarif');
"

# Check for critical issues
if grep -q '"level": "error"' $OUTPUT_DIR/*_$DATE.sarif; then
    echo "CRITICAL: Database issues found!"
    # Send alert
fi
```
