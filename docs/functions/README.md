# PGLinter Functions Reference

Comprehensive documentation for all PGLinter functions providing database analysis, rule management, and configuration capabilities.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Analysis Functions](#analysis-functions)
3. [Rule Management Functions](#rule-management-functions)
4. [Import/Export Functions](#importexport-functions)
5. [Configuration Management](#configuration-management)
6. [Practical Usage](#practical-usage)

---

## Quick Start

```sql
-- Comprehensive database analysis (recommended for first-time users)
SELECT pglinter.check_all();

-- Basic database analysis with file output
SELECT pglinter.perform_base_check('/tmp/analysis.sarif');

-- Check what rules are available
SELECT pglinter.list_rules();

-- Enable/disable specific rules
SELECT pglinter.enable_rule('B001');
SELECT pglinter.disable_rule('B004');
```

---

## Analysis Functions

Core analysis functions that execute rule checks and generate database assessment reports.

### perform_base_check([output_file])

Executes all enabled base rules (B-series) for comprehensive database analysis, including structural integrity and best practice violations.

#### perform_base_check Syntax

```sql
SELECT pglinter.perform_base_check([output_file text]);
```

#### perform_base_check Parameters

- `output_file` (optional): Path to save SARIF results

#### perform_base_check Returns

- When `output_file` specified: Success message
- When no file specified: Table with rule results

#### perform_base_check Examples

```sql
-- Analyze entire database
SELECT * FROM pglinter.perform_base_check();

-- Save results to SARIF file
SELECT pglinter.perform_base_check('/tmp/database_analysis.sarif');

-- Quick check with count only
SELECT count(*) as issues_found FROM pglinter.perform_base_check();

-- Dynamic filename with timestamp
SELECT pglinter.perform_base_check(
    '/logs/base_' || to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') || '.sarif'
);
```

#### perform_base_check Rule Coverage

- **B001**: Tables without primary keys
- **B002**: Redundant indexes detection
- **B003**: Foreign keys not indexed
- **B004**: Unused indexes analysis
- **B005**: Public schema usage patterns
- **B006**: Uppercase object names convention
- **B007**: Tables not selected in queries
- **B008**: Foreign keys outside schema boundaries

---

### perform_cluster_check([output_file])

Executes all enabled cluster rules (C-series) for database-wide security and configuration analysis at the instance level.

#### perform_cluster_check Syntax

```sql
SELECT pglinter.perform_cluster_check([output_file text]);
```

#### perform_cluster_check Parameters

- `output_file` (optional): Path to save SARIF results

#### perform_cluster_check Returns

- When `output_file` specified: Success message
- When no file specified: Table with rule results

#### perform_cluster_check Examples

```sql
-- Analyze cluster configuration
SELECT * FROM pglinter.perform_cluster_check();

-- Save cluster analysis with timestamp
SELECT pglinter.perform_cluster_check('/logs/cluster_' || to_char(now(), 'YYYY-MM-DD') || '.sarif');

-- Check for security issues only
SELECT * FROM pglinter.perform_cluster_check() WHERE level = 'error';
```

#### perform_cluster_check Rule Coverage

- **C002**: HBA security configuration vulnerabilities



---

### perform_schema_check([output_file])

Executes all enabled schema rules (S-series) for schema-level analysis and access control validation.

#### perform_schema_check Syntax

```sql
SELECT pglinter.perform_schema_check([output_file text]);
```

#### perform_schema_check Parameters

- `output_file` (optional): Path to save SARIF results

#### perform_schema_check Returns

- When `output_file` specified: Success message
- When no file specified: Table with rule results

#### perform_schema_check Examples

```sql
-- Analyze schemas
SELECT * FROM pglinter.perform_schema_check();

-- Save schema analysis
SELECT pglinter.perform_schema_check('/tmp/schema_analysis.sarif');

-- Check specific schema issues
SELECT * FROM pglinter.perform_schema_check() WHERE message LIKE '%permission%';
```

#### perform_schema_check Rule Coverage

- **S001**: Schema with no default role granted

---

### check_all()

Executes all analysis functions (base, cluster, table, and schema checks) in a comprehensive workflow with formatted output and status reporting.

#### check_all Syntax

```sql
SELECT pglinter.check_all();
```

#### check_all Parameters

None - this function always outputs to console and does not support file output.

#### check_all Returns

- `boolean`: true if all checks completed successfully, false if any check encountered errors

#### check_all Examples

```sql
-- Run comprehensive analysis of entire database
SELECT pglinter.check_all();

-- Use in conditional logic
DO $$
BEGIN
    IF pglinter.check_all() THEN
        RAISE NOTICE 'All database checks passed!';
    ELSE
        RAISE NOTICE 'Some database issues found - review output above';
    END IF;
END $$;
```

#### check_all Behavior

The function executes checks in the following order:

1. **📋 BASE CHECKS**: Runs `perform_base_check()` for structural integrity
2. **🖥️ CLUSTER CHECKS**: Runs `perform_cluster_check()` for instance-level security
3. **📊 TABLE CHECKS**: Runs `perform_table_check()` for table-level analysis
4. **🗂️ SCHEMA CHECKS**: Runs `perform_schema_check()` for schema-level validation

#### check_all Features

- **Formatted Output**: Uses emojis and section headers for clear organization
- **Progress Indicators**: Shows which check category is currently running
- **Comprehensive Summary**: Reports overall success/failure status at the end
- **Error Resilience**: Continues running remaining checks even if individual checks find issues
- **Console Only**: Always outputs to console for interactive use

#### check_all Use Cases

- **Daily Health Checks**: Quick comprehensive database assessment
- **Pre-deployment Validation**: Ensure database meets standards before releases
- **Interactive Analysis**: User-friendly output for manual database reviews
- **Troubleshooting**: Get complete overview when investigating database issues

---

### Convenience Analysis Functions

The following convenience functions provide simplified access to individual analysis categories without file output options:

#### check_base(), check_cluster(), check_table(), check_schema()

Simplified versions of the main analysis functions that always output to console.

##### Convenience Functions Syntax

```sql
SELECT pglinter.check_base();     -- Equivalent to perform_base_check() without file output
SELECT pglinter.check_cluster();  -- Equivalent to perform_cluster_check() without file output
SELECT pglinter.check_table();    -- Equivalent to perform_table_check() without file output
SELECT pglinter.check_schema();   -- Equivalent to perform_schema_check() without file output
```

##### Convenience Functions Parameters

None - these functions have no parameters and always output to console.

##### Convenience Functions Returns

- `boolean`: true if the specific check completed successfully, false if errors occurred

##### Convenience Functions Examples

```sql
-- Run individual check categories
SELECT pglinter.check_base();
SELECT pglinter.check_table();

-- Chain specific checks
SELECT pglinter.check_base() AND pglinter.check_table() AS core_checks_passed;
```

---

## Rule Management Functions

Functions for controlling which rules are active and understanding rule configurations.

### list_rules()

Displays a formatted list of all available rules with their current status and names, providing a visual overview.

#### list_rules Syntax

```sql
SELECT pglinter.list_rules();
```

#### list_rules Returns

- `text`: Formatted table showing all rules with status icons, codes, status, and names

#### list_rules Examples

```sql
-- Show formatted list of all rules
SELECT pglinter.list_rules();
```

#### list_rules Sample Output

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

#### Features

- **Visual Status**: Uses ✅ for enabled rules and ❌ for disabled rules
- **Clear Format**: Shows rule code, status, and descriptive name
- **Complete List**: Displays all available rules in the system
- **Sorted Output**: Rules are ordered by rule code for easy scanning

---

### show_rules()

Displays detailed information about all available rules in tabular format, suitable for programmatic processing.

#### show_rules Syntax

```sql
SELECT * FROM pglinter.show_rules();
```

#### show_rules Returns

Table with columns:

- `rule_code`: Rule identifier (e.g., 'B001')
- `description`: Brief rule description
- `enabled`: Whether rule is currently enabled
- `scope`: Rule category (Base, Cluster, Table, Schema)

#### show_rules Examples

```sql
-- Show all rules
SELECT * FROM pglinter.show_rules();

-- Show only enabled rules
SELECT * FROM pglinter.show_rules() WHERE enabled = true;

-- Show rules by category
SELECT * FROM pglinter.show_rules() WHERE rule_code LIKE 'B%';

-- Count rules by status
SELECT enabled, count(*) as rule_count
FROM pglinter.show_rules()
GROUP BY enabled;
```

---

### is_rule_enabled(rule_code)

Checks if a specific rule is currently enabled, useful for conditional logic and validation.

#### is_rule_enabled Syntax

```sql
SELECT pglinter.is_rule_enabled(rule_code text);
```

#### is_rule_enabled Parameters

- `rule_code`: Rule identifier (e.g., 'B001')

#### is_rule_enabled Returns

- `boolean`: true if enabled, false if disabled, NULL if rule doesn't exist

#### is_rule_enabled Examples

```sql
-- Check if B001 is enabled
SELECT pglinter.is_rule_enabled('B001');

-- Check multiple rules
SELECT rule_code, pglinter.is_rule_enabled(rule_code) as enabled
FROM (VALUES ('B001'), ('B002'), ('T001')) AS rules(rule_code);

-- Conditional analysis based on rule status
SELECT CASE
    WHEN pglinter.is_rule_enabled('B001') THEN 'Primary key analysis enabled'
    ELSE 'Primary key analysis disabled'
END as status;
```

---

### enable_rule(rule_code)

Enables a specific rule for future analysis, allowing fine-grained control over rule activation.

#### enable_rule Syntax

```sql
SELECT pglinter.enable_rule(rule_code text);
```

#### enable_rule Parameters

- `rule_code`: Rule identifier to enable

#### enable_rule Returns

- `text`: Success or error message

#### enable_rule Examples

```sql
-- Enable a specific rule
SELECT pglinter.enable_rule('B001');

-- Enable multiple rules in sequence
SELECT pglinter.enable_rule('B001'),
       pglinter.enable_rule('B002'),
       pglinter.enable_rule('T001');

-- Enable all base rules
SELECT rule_code, pglinter.enable_rule(rule_code) as result
FROM pglinter.show_rules()
WHERE rule_code LIKE 'B%';

-- Enable rules with validation
SELECT CASE
    WHEN pglinter.is_rule_enabled('B001') THEN 'Already enabled'
    ELSE pglinter.enable_rule('B001')
END as result;
```

---

### disable_rule(rule_code)

Disables a specific rule from future analysis, useful for excluding irrelevant checks.

#### disable_rule Syntax

```sql
SELECT pglinter.disable_rule(rule_code text);
```

#### disable_rule Parameters

- `rule_code`: Rule identifier to disable

#### disable_rule Returns

- `text`: Success or error message

#### disable_rule Examples

```sql
-- Disable a specific rule
SELECT pglinter.disable_rule('B004');

-- Disable performance-related rules for development
SELECT pglinter.disable_rule('B004'), -- Unused indexes
       pglinter.disable_rule('T007'), -- Table unused indexes
       pglinter.disable_rule('T005'); -- High seq scans

-- Disable rules based on environment
SELECT rule_code, pglinter.disable_rule(rule_code) as result
FROM pglinter.show_rules()
WHERE rule_code IN ('T004', 'T005', 'T006'); -- Performance rules
```

---

### explain_rule(rule_code)

Provides detailed information about a specific rule including description, purpose, and remediation guidance.

#### explain_rule Syntax

```sql
SELECT pglinter.explain_rule(rule_code text);
```

#### explain_rule Parameters

- `rule_code`: Rule identifier to explain

#### explain_rule Returns

- `text`: Detailed rule explanation with description and numbered fix recommendations

#### explain_rule Examples

```sql
-- Get explanation for B002
SELECT pglinter.explain_rule('B002');

-- Get explanations for all enabled rules
SELECT rule_code, pglinter.explain_rule(rule_code) as explanation
FROM pglinter.show_rules()
WHERE enabled = true
ORDER BY rule_code;

-- Interactive help system
SELECT pglinter.explain_rule(rule_code) as help_text
FROM pglinter.show_rules()
WHERE rule_code = 'T005';
```

#### explain_rule Sample Output

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

Enables all currently disabled rules in the system, useful for comprehensive analysis or resetting configurations.

#### enable_all_rules Syntax

```sql
SELECT pglinter.enable_all_rules();
```

#### enable_all_rules Returns

- `text`: Success message with count of rules enabled

#### enable_all_rules Examples

```sql
-- Enable all disabled rules
SELECT pglinter.enable_all_rules();
-- Returns: "Enabled 5 rules"

-- Check effect of enabling all rules
SELECT count(*) as total_rules,
       sum(case when enabled then 1 else 0 end) as enabled_rules
FROM pglinter.show_rules();

-- Enable all then selectively disable
SELECT pglinter.enable_all_rules();
SELECT pglinter.disable_rule('T005'); -- Disable performance rule
```

---

### disable_all_rules()

Disables all currently enabled rules in the system, useful for starting with a clean slate or maintenance mode.

#### disable_all_rules Syntax

```sql
SELECT pglinter.disable_all_rules();
```

#### disable_all_rules Returns

- `text`: Success message with count of rules disabled

#### disable_all_rules Examples

```sql
-- Disable all enabled rules
SELECT pglinter.disable_all_rules();
-- Returns: "Disabled 12 rules"

-- Selective re-enable for critical checks only
SELECT pglinter.enable_rule('B001'),  -- Critical: primary keys
       pglinter.enable_rule('C002');  -- Critical: security

-- Maintenance mode setup
SELECT pglinter.disable_all_rules(); -- Disable everything
-- Perform maintenance...
SELECT pglinter.enable_all_rules();  -- Re-enable after maintenance
```

---

### update_rule_levels(rule_code, warning_level, error_level)

Updates the warning and error thresholds for configurable rules, allowing customization of sensitivity levels.

#### update_rule_levels Syntax

```sql
SELECT pglinter.update_rule_levels(
    rule_code text,
    warning_level numeric,
    error_level numeric
);
```

#### update_rule_levels Parameters

- `rule_code`: Rule identifier to update (e.g., 'T005')
- `warning_level`: Warning threshold (NULL to keep current value)
- `error_level`: Error threshold (NULL to keep current value)

#### update_rule_levels Returns

- `text`: Success message confirming the update

#### update_rule_levels Examples

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

-- Environment-specific configurations
-- Development: Relaxed thresholds
SELECT pglinter.update_rule_levels('T005', 70.0, 95.0);

-- Production: Strict thresholds
SELECT pglinter.update_rule_levels('T005', 30.0, 60.0);
```

#### update_rule_levels Notes

- Only applies to rules with configurable thresholds (currently T005)
- Use NULL to preserve existing values for either parameter
- For T005: values represent percentage thresholds for sequential scan ratio

---

### get_rule_levels(rule_code)

Retrieves the current warning and error threshold levels for a rule, useful for configuration management.

#### get_rule_levels Syntax

```sql
SELECT pglinter.get_rule_levels(rule_code text);
```

#### get_rule_levels Parameters

- `rule_code`: Rule identifier to query

#### get_rule_levels Returns

- `text`: Current warning and error levels, or default values if rule not configured

#### get_rule_levels Examples

```sql
-- Get current levels for T005
SELECT pglinter.get_rule_levels('T005');
-- Returns: "Rule T005: warning_level=50, error_level=90"

-- Check levels for all configurable rules
SELECT 'T005' as rule_code, pglinter.get_rule_levels('T005') as levels;

-- Validate configuration before update
SELECT pglinter.get_rule_levels('T005') as current_config;
SELECT pglinter.update_rule_levels('T005', 40.0, 80.0);
SELECT pglinter.get_rule_levels('T005') as new_config;
```

#### get_rule_levels Notes

- Returns default values (warning=50, error=90) for unconfigured rules
- Currently only T005 supports configurable levels
- Values for T005 represent percentage thresholds

---

## Import/Export Functions

Functions for managing rule configurations as code, enabling version control and environment synchronization.

### export_rules_to_yaml()

Exports all rules and their configurations to YAML format for backup, version control, or environment migration.

#### export_rules_to_yaml Syntax

```sql
SELECT pglinter.export_rules_to_yaml();
```

#### export_rules_to_yaml Returns

- `text`: YAML-formatted string containing all rules with metadata, configuration, and timestamps

#### export_rules_to_yaml Examples

```sql
-- Export all rules to view YAML structure
SELECT pglinter.export_rules_to_yaml();

-- Save export to a variable for processing
\set yaml_export `SELECT pglinter.export_rules_to_yaml();`
\echo :yaml_export

-- Use in shell script
psql -c "SELECT pglinter.export_rules_to_yaml();" > /tmp/rules_backup.yaml
```

#### Sample Output

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
  T005:
    name: "Sequential scan analysis"
    enabled: true
    scope: "TABLE"
    warning_level: 50
    error_level: 90
```

---

### export_rules_to_file(file_path)

Exports all rules and configurations directly to a YAML file on the filesystem for automated backups and deployments.

#### export_rules_to_file Syntax

```sql
SELECT pglinter.export_rules_to_file(file_path text);
```

#### export_rules_to_file Parameters

- `file_path`: Absolute path where the YAML file will be created

#### export_rules_to_file Returns

- `text`: Success message confirming export completion and file location

#### export_rules_to_file Examples

```sql
-- Export to a specific file
SELECT pglinter.export_rules_to_file('/tmp/pglinter_rules.yaml');

-- Export with timestamp in filename
SELECT pglinter.export_rules_to_file(
    '/backups/rules_' || to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') || '.yaml'
);

-- Export for version control
SELECT pglinter.export_rules_to_file('/project/config/pglinter_rules.yaml');

-- Automated backup script
SELECT pglinter.export_rules_to_file('/daily_backups/' || current_date || '_rules.yaml');
```

#### Notes

- Requires PostgreSQL to have write access to the specified directory
- Creates a complete backup of all rule configurations
- Includes metadata about export time and rule counts
- Can be used for version control of rule configurations

---

### import_rules_from_yaml(yaml_content)

Imports rule configurations from a YAML string, enabling programmatic rule management and configuration as code.

#### import_rules_from_yaml Syntax

```sql
SELECT pglinter.import_rules_from_yaml(yaml_content text);
```

#### import_rules_from_yaml Parameters

- `yaml_content`: YAML-formatted string containing rule definitions

#### import_rules_from_yaml Returns

- `text`: Summary of import operation including counts of new and updated rules

#### import_rules_from_yaml Examples

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

-- Import configuration changes
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

-- Environment-specific rule configuration
SELECT pglinter.import_rules_from_yaml('
metadata:
  format_version: "1.0"
  environment: "production"
rules:
  T005:
    enabled: true
    warning_level: 20
    error_level: 50
  B004:
    enabled: false
');
```

---

### import_rules_from_file(file_path)

Imports rule configurations from a YAML file on the filesystem, enabling automated deployments and configuration management.

#### import_rules_from_file Syntax

```sql
SELECT pglinter.import_rules_from_file(file_path text);
```

#### import_rules_from_file Parameters

- `file_path`: Absolute path to the YAML file containing rule definitions

#### import_rules_from_file Returns

- `text`: Summary of import operation including counts of new and updated rules

#### import_rules_from_file Examples

```sql
-- Import from a configuration file
SELECT pglinter.import_rules_from_file('/config/pglinter_rules.yaml');

-- Import from backup
SELECT pglinter.import_rules_from_file('/backups/rules_2023-10-15.yaml');

-- Import development configuration
SELECT pglinter.import_rules_from_file('/project/dev_rules.yaml');

-- Deployment automation
SELECT pglinter.import_rules_from_file('/deploy/production_rules.yaml');
```

#### Use Cases

```sql
-- 1. Configuration Management
-- Export current production configuration
SELECT pglinter.export_rules_to_file('/backups/prod_rules.yaml');

-- Import to development environment
SELECT pglinter.import_rules_from_file('/backups/prod_rules.yaml');

-- 2. Environment-Specific Rules
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

-- 3. Version Control Integration
-- Export for commit
SELECT pglinter.export_rules_to_file('/project/.pglinter/rules.yaml');

-- Import after deployment
SELECT pglinter.import_rules_from_file('/project/.pglinter/rules.yaml');
```

---

## Configuration Management

Advanced configuration options and rule category management.

### Configurable Rule Thresholds

Some rules support configurable warning and error thresholds that can be customized based on your environment's needs.

#### Supported Configurable Rules

##### T005: Sequential Scan Analysis

Rule T005 analyzes tables for potential missing indexes by calculating the percentage of tuples accessed via sequential scans versus total tuples accessed.

#### Default Thresholds

- **Warning**: 50% (when ≥50% of tuple access is via sequential scans)
- **Error**: 90% (when ≥90% of tuple access is via sequential scans)

#### Threshold Management

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

#### Understanding T005 Results

```sql
-- Example T005 output interpretation
-- "Table 'orders' has high sequential scan ratio: 75.5% (warning threshold: 50%)"
-- This means 75.5% of tuple access on the 'orders' table uses sequential scans
```

#### Best Practices for Threshold Configuration

1. **Development Environment**: Use higher thresholds (70%/95%) to reduce noise
2. **Staging Environment**: Use moderate thresholds (40%/80%) for testing
3. **Production Environment**: Use sensitive thresholds (30%/70%) for optimal performance
4. **High-Traffic Systems**: Consider very sensitive thresholds (20%/50%)

#### Future Configurable Rules

Additional rules may support configurable thresholds in future versions. Use `get_rule_levels()` to check if a rule supports configuration:

```sql
-- Check if a rule supports configuration
SELECT pglinter.get_rule_levels('B001');
-- Returns default values if not configurable
```

---

### Rule Categories

PGLinter organizes rules into logical categories for easier management and understanding.

#### Base Rules (B-series)

Fundamental database structure and best practice checks:

- **B001**: Tables without primary keys
- **B002**: Redundant indexes detection
- **B003**: Foreign keys not indexed
- **B004**: Unused indexes analysis
- **B005**: Public schema usage patterns
- **B006**: Uppercase object names convention
- **B007**: Tables not selected in queries
- **B008**: Foreign keys outside schema boundaries

#### Cluster Rules (C-series)

Database instance-level configuration and security:

- **C002**: HBA security configuration vulnerabilities

#### Table Rules (T-series)

Detailed table-level analysis:

- **T001**: Table without primary key
- **T002**: Table with redundant indexes
- **T003**: Table with foreign keys not indexed
- **T004**: Table with potential missing indexes
- **T005**: Table with foreign keys outside schema (configurable thresholds)
- **T006**: Table with unused indexes
- **T007**: Table with foreign key type mismatch
- **T008**: Table with no roles granted
- **T009**: Reserved keywords in object names
- **T010**: Table with sensitive columns

#### Schema Rules (S-series)

Schema-level access control and organization:

- **S001**: Schema with no default role granted

---

### Output Formats

#### Console Output

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

#### SARIF File Output

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

---

## Practical Usage

Real-world usage patterns, error handling, and integration guidance.

### Error Handling

#### Common Errors and Solutions

##### 1. Permission Denied

```sql
ERROR: permission denied for function perform_base_check
```

**Solution**: Ensure user has appropriate privileges

```sql
-- Grant necessary permissions
GRANT USAGE ON SCHEMA pglinter TO analysis_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pglinter TO analysis_user;
```

##### 2. File Write Error

```sql
ERROR: could not open file "/invalid/path/results.sarif" for writing
```

**Solution**: Check file path permissions and PostgreSQL file access settings

```sql
-- Check PostgreSQL file permissions
SHOW data_directory;
-- Ensure write access to target directory
```

##### 3. Invalid Rule Code

```sql
NOTICE: Rule 'INVALID' not found
```

**Solution**: Use valid rule codes from `show_rules()`

```sql
-- Get valid rule codes
SELECT rule_code FROM pglinter.show_rules();
```

#### Error Response Format

Functions return descriptive error messages:

```sql
-- Invalid rule code
SELECT pglinter.enable_rule('INVALID');
-- Returns: "Rule 'INVALID' not found"

-- File permission error
SELECT pglinter.perform_base_check('/root/protected.sarif');
-- Returns: "Error: could not write to file '/root/protected.sarif'"
```

---

### Performance Considerations

#### Resource Usage

- **Memory**: Rules analyze metadata, not data rows (low memory usage)
- **CPU**: Analysis scales with number of database objects
- **I/O**: File output requires write permissions
- **Locks**: Uses read-only queries (minimal locking)

#### Optimization Tips

##### 1. Selective Analysis

```sql
-- Run only specific rule categories
SELECT pglinter.perform_table_check(); -- Only table rules
SELECT pglinter.perform_cluster_check(); -- Only cluster rules

-- Run specific rules only
SELECT pglinter.disable_all_rules();
SELECT pglinter.enable_rule('B001');
SELECT pglinter.enable_rule('T001');
SELECT pglinter.perform_base_check();
```

##### 2. Scheduled Analysis

```sql
-- Run during low-usage periods using pg_cron
SELECT cron.schedule('pglinter-weekly', '0 2 * * 0',
    'SELECT pglinter.perform_base_check(''/logs/weekly.sarif'');');

-- Daily table analysis
SELECT cron.schedule('pglinter-daily-tables', '0 3 * * *',
    'SELECT pglinter.perform_table_check(''/logs/tables_'' || current_date || ''.sarif'');');
```

##### 3. Rule Management for Performance

```sql
-- Disable expensive rules in development
SELECT pglinter.disable_rule('T005'); -- Sequential scan analysis
SELECT pglinter.disable_rule('B004'); -- Unused index detection

-- Enable performance rules only in production
SELECT CASE
    WHEN current_setting('server_version_num')::int >= 130000
    THEN pglinter.enable_rule('T005')
    ELSE 'Skipped for older PostgreSQL version'
END;
```

---

### Integration Examples

#### CI/CD Pipeline Integration

##### GitHub Actions Example

```yaml
name: Database Analysis
on: [push, pull_request]

jobs:
  database-lint:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Setup Database
        run: |
          psql -h localhost -U postgres -c "CREATE EXTENSION pglinter;"
          psql -h localhost -U postgres -f schema.sql
        env:
          PGPASSWORD: postgres

      - name: Run PGLinter Analysis
        run: |
          psql -h localhost -U postgres -c "
            SELECT pglinter.perform_base_check('/tmp/results.sarif');
            SELECT pglinter.perform_table_check('/tmp/table_results.sarif');
          "
        env:
          PGPASSWORD: postgres

      - name: Upload SARIF Results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: /tmp/results.sarif

      - name: Check for Critical Issues
        run: |
          if grep -q '"level": "error"' /tmp/results.sarif; then
            echo "CRITICAL: Database issues found!"
            exit 1
          fi
```

##### GitLab CI Example

```yaml
database-analysis:
  stage: test
  services:
    - postgres:15
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
  before_script:
    - psql -h postgres -U postgres -d testdb -c "CREATE EXTENSION pglinter;"
  script:
    - psql -h postgres -U postgres -d testdb -c "
        SELECT pglinter.perform_base_check('/tmp/base_results.sarif');
        SELECT pglinter.perform_table_check('/tmp/table_results.sarif');
      "
  artifacts:
    reports:
      junit: /tmp/*_results.sarif
    expire_in: 1 week
  only:
    - merge_requests
    - main
```

#### Monitoring and Alerting

##### Daily Monitoring Script

```bash
#!/bin/bash
# daily_db_check.sh

DB_NAME="production_db"
OUTPUT_DIR="/var/log/pglinter"
DATE=$(date +%Y-%m-%d)
ALERT_EMAIL="dba-team@company.com"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run comprehensive analysis
psql -d "$DB_NAME" -c "
-- Configure for production environment
SELECT pglinter.update_rule_levels('T005', 30.0, 60.0);

-- Run all checks
SELECT pglinter.perform_base_check('$OUTPUT_DIR/base_$DATE.sarif');
SELECT pglinter.perform_table_check('$OUTPUT_DIR/table_$DATE.sarif');
SELECT pglinter.perform_cluster_check('$OUTPUT_DIR/cluster_$DATE.sarif');
SELECT pglinter.perform_schema_check('$OUTPUT_DIR/schema_$DATE.sarif');
"

# Check for critical issues
CRITICAL_COUNT=$(grep -c '"level": "error"' "$OUTPUT_DIR"/*_"$DATE".sarif 2>/dev/null || echo 0)
WARNING_COUNT=$(grep -c '"level": "warning"' "$OUTPUT_DIR"/*_"$DATE".sarif 2>/dev/null || echo 0)

# Generate summary report
cat > "$OUTPUT_DIR/summary_$DATE.txt" << EOF
PGLinter Daily Report - $(date)
===============================
Database: $DB_NAME
Critical Issues: $CRITICAL_COUNT
Warnings: $WARNING_COUNT

Files Generated:
- Base Analysis: $OUTPUT_DIR/base_$DATE.sarif
- Table Analysis: $OUTPUT_DIR/table_$DATE.sarif
- Cluster Analysis: $OUTPUT_DIR/cluster_$DATE.sarif
- Schema Analysis: $OUTPUT_DIR/schema_$DATE.sarif
EOF

# Send alerts if critical issues found
if [ "$CRITICAL_COUNT" -gt 0 ]; then
    mail -s "CRITICAL: PGLinter found $CRITICAL_COUNT critical database issues" \
         "$ALERT_EMAIL" < "$OUTPUT_DIR/summary_$DATE.txt"

    # Log to syslog
    logger -p local0.err "PGLinter: $CRITICAL_COUNT critical database issues found in $DB_NAME"
fi

# Cleanup old files (keep 30 days)
find "$OUTPUT_DIR" -name "*.sarif" -mtime +30 -delete
find "$OUTPUT_DIR" -name "summary_*.txt" -mtime +30 -delete
```

#### Application Integration

##### Python Integration Example

```python
import psycopg2
import json
import logging
from typing import Dict, List, Optional

class PGLinterClient:
    def __init__(self, connection_string: str):
        self.conn = psycopg2.connect(connection_string)
        self.logger = logging.getLogger(__name__)

    def run_analysis(self, output_file: Optional[str] = None) -> Dict:
        """Run comprehensive PGLinter analysis"""
        results = {}

        try:
            with self.conn.cursor() as cursor:
                # Run base check
                if output_file:
                    cursor.execute(
                        "SELECT pglinter.perform_base_check(%s)",
                        (f"{output_file}_base.sarif",)
                    )
                    results['base'] = cursor.fetchone()[0]
                else:
                    cursor.execute("SELECT * FROM pglinter.perform_base_check()")
                    results['base'] = cursor.fetchall()

                # Run table check
                if output_file:
                    cursor.execute(
                        "SELECT pglinter.perform_table_check(%s)",
                        (f"{output_file}_table.sarif",)
                    )
                    results['table'] = cursor.fetchone()[0]
                else:
                    cursor.execute("SELECT * FROM pglinter.perform_table_check()")
                    results['table'] = cursor.fetchall()

                return results

        except Exception as e:
            self.logger.error(f"PGLinter analysis failed: {e}")
            raise

    def configure_rules(self, rules_config: Dict) -> None:
        """Configure rules based on environment"""
        try:
            with self.conn.cursor() as cursor:
                for rule_code, config in rules_config.items():
                    if config.get('enabled', True):
                        cursor.execute(
                            "SELECT pglinter.enable_rule(%s)",
                            (rule_code,)
                        )
                    else:
                        cursor.execute(
                            "SELECT pglinter.disable_rule(%s)",
                            (rule_code,)
                        )

                    # Update thresholds if provided
                    if 'warning_level' in config or 'error_level' in config:
                        cursor.execute(
                            "SELECT pglinter.update_rule_levels(%s, %s, %s)",
                            (
                                rule_code,
                                config.get('warning_level'),
                                config.get('error_level')
                            )
                        )

                self.conn.commit()

        except Exception as e:
            self.conn.rollback()
            self.logger.error(f"Rule configuration failed: {e}")
            raise

# Usage example
if __name__ == "__main__":
    client = PGLinterClient("postgresql://user:pass@localhost/db")

    # Configure for production environment
    production_rules = {
        'T005': {'enabled': True, 'warning_level': 30.0, 'error_level': 60.0},
        'B004': {'enabled': True},
        'C002': {'enabled': True}
    }

    client.configure_rules(production_rules)

    # Run analysis
    results = client.run_analysis('/tmp/prod_analysis')

    print(f"Analysis completed: {results}")
```

##### Node.js Integration Example

```javascript
const { Pool } = require('pg');
const fs = require('fs').promises;

class PGLinterService {
    constructor(connectionConfig) {
        this.pool = new Pool(connectionConfig);
    }

    async runFullAnalysis(outputPath = null) {
        const client = await this.pool.connect();

        try {
            const results = {};

            // Run comprehensive analysis
            const analysisTypes = ['base', 'table', 'cluster', 'schema'];

            for (const type of analysisTypes) {
                if (outputPath) {
                    const query = `SELECT pglinter.perform_${type}_check($1)`;
                    const result = await client.query(query, [`${outputPath}_${type}.sarif`]);
                    results[type] = { message: result.rows[0][Object.keys(result.rows[0])[0]] };
                } else {
                    const query = `SELECT * FROM pglinter.perform_${type}_check()`;
                    const result = await client.query(query);
                    results[type] = result.rows;
                }
            }

            return results;

        } finally {
            client.release();
        }
    }

    async exportConfiguration(filePath) {
        const client = await this.pool.connect();

        try {
            const result = await client.query('SELECT pglinter.export_rules_to_yaml()');
            const yamlContent = result.rows[0].export_rules_to_yaml;

            await fs.writeFile(filePath, yamlContent);
            console.log(`Configuration exported to ${filePath}`);

        } finally {
            client.release();
        }
    }

    async importConfiguration(filePath) {
        const client = await this.pool.connect();

        try {
            const result = await client.query(
                'SELECT pglinter.import_rules_from_file($1)',
                [filePath]
            );

            console.log('Import result:', result.rows[0].import_rules_from_file);

        } finally {
            client.release();
        }
    }

    async close() {
        await this.pool.end();
    }
}

// Usage
async function main() {
    const linter = new PGLinterService({
        host: 'localhost',
        database: 'myapp',
        user: 'postgres',
        password: 'password'
    });

    try {
        // Export current configuration
        await linter.exportConfiguration('/config/current_rules.yaml');

        // Run analysis
        const results = await linter.runFullAnalysis('/tmp/analysis');

        console.log('Analysis Results:');
        Object.entries(results).forEach(([type, data]) => {
            console.log(`${type}: ${JSON.stringify(data, null, 2)}`);
        });

    } finally {
        await linter.close();
    }
}

main().catch(console.error);
```

---

This completes the comprehensive PGLinter Functions Reference. The documentation now provides:

- **Clear organization** with logical sections and subsections
- **Comprehensive examples** for each function
- **Practical usage patterns** for real-world scenarios
- **Integration guidance** for CI/CD and monitoring
- **Error handling** and troubleshooting information
- **Performance considerations** and optimization tips
- **Complete rule coverage** with detailed explanations

The reference serves as both a learning resource for new users and a comprehensive reference for experienced practitioners implementing PGLinter in production environments.
