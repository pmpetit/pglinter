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
-- Run all enabled rules and retrieve violations as a table
SELECT * FROM pglinter.get_violations();

-- Filter violations by rule
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B001';

-- Check what rules are available
SELECT pglinter.list_rules();

-- Enable/disable specific rules
SELECT pglinter.enable_rule('B001');
SELECT pglinter.disable_rule('B004');
```

---

## Analysis Functions

Core analysis functions that execute rule checks and return database assessment results.

### get_violations()

Executes all enabled rules and returns all detected violations as a table, including structural integrity, security, and best practice violations.

#### get_violations Syntax

```sql
SELECT * FROM pglinter.get_violations();
```

#### get_violations Returns

Table with columns:

- `rule_code` (TEXT): The rule identifier (e.g., 'B001')
- `classid` (OID): Object class identifier
- `objid` (OID): Object identifier
- `objsubid` (INTEGER): Object sub-identifier
- `message` (TEXT): Human-readable violation message

#### get_violations Examples

```sql
-- Get all violations for enabled rules
SELECT * FROM pglinter.get_violations();

-- Count violations per rule
SELECT rule_code, count(*) AS violation_count
FROM pglinter.get_violations()
GROUP BY rule_code
ORDER BY violation_count DESC;

-- Filter by specific rule
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B001';

-- Check if any violations exist
SELECT EXISTS (SELECT 1 FROM pglinter.get_violations());
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
- `message`: Brief rule message.
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
       pglinter.disable_rule('T005'); -- High seq scans

-- Disable rules based on environment
SELECT rule_code, pglinter.disable_rule(rule_code) as result
FROM pglinter.show_rules()
WHERE rule_code IN ('B004');
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
WHERE rule_code = 'B001';
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
    message: "Tables without primary key found"
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
');

-- Import configuration changes
SELECT pglinter.import_rules_from_yaml('
metadata:
  format_version: "1.0"
rules:
  B001:
    enabled: false
  T005:
    enabled: true
');

-- Environment-specific rule configuration
SELECT pglinter.import_rules_from_yaml('
metadata:
  format_version: "1.0"
  environment: "production"
rules:
  T005:
    enabled: true
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
');

-- Production: Strict rules
SELECT pglinter.import_rules_from_yaml('
rules:
  T005:
');

-- 3. Version Control Integration
-- Export for commit
SELECT pglinter.export_rules_to_file('/project/.pglinter/rules.yaml');

-- Import after deployment
SELECT pglinter.import_rules_from_file('/project/.pglinter/rules.yaml');
```

---
