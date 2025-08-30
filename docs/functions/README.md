# Functions Reference

Complete reference for all PG Linter functions and their usage.

## Core Functions

### perform_base_check([output_file])

Executes all enabled base rules (B-series) and returns or saves results.

**Syntax:**
```sql
SELECT pglinter.perform_base_check([output_file text]);
```

**Parameters:**
- `output_file` (optional): Path to save SARIF results. If omitted, results are returned to console.

**Returns:**
- When `output_file` specified: Success message
- When no file specified: Table with rule results

**Examples:**
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

**Rule Coverage:**
- B001: Tables without primary keys
- B002: Redundant indexes
- B003: Tables without indexes on foreign keys
- B004: Unused indexes
- B005: Unsecured public schema
- B006: Tables with uppercase names/columns

---

### perform_cluster_check([output_file])

Executes all enabled cluster rules (C-series) for PostgreSQL configuration analysis.

**Syntax:**
```sql
SELECT pglinter.perform_cluster_check([output_file text]);
```

**Parameters:**
- `output_file` (optional): Path to save SARIF results

**Returns:**
- When `output_file` specified: Success message
- When no file specified: Table with rule results

**Examples:**
```sql
-- Check cluster configuration
SELECT * FROM pglinter.perform_cluster_check();

-- Save cluster analysis
SELECT pglinter.perform_cluster_check('/tmp/cluster_analysis.sarif');
```

**Rule Coverage:**
- C001: Memory configuration issues
- C002: Insecure pg_hba.conf entries

---

### perform_table_check([output_file])

Executes all enabled table rules (T-series) for individual table analysis.

**Syntax:**
```sql
SELECT pglinter.perform_table_check([output_file text]);
```

**Parameters:**
- `output_file` (optional): Path to save SARIF results

**Returns:**
- When `output_file` specified: Success message
- When no file specified: Table with rule results

**Examples:**
```sql
-- Analyze all tables
SELECT * FROM pglinter.perform_table_check();

-- Save table analysis
SELECT pglinter.perform_table_check('/tmp/table_analysis.sarif');
```

**Rule Coverage:**
- T001: Individual tables without primary keys
- T002: Tables without any indexes
- T003: Tables with redundant indexes
- T004: Tables with foreign keys not indexed
- T005: Tables with potential missing indexes
- T006: Tables with foreign keys referencing other schemas
- T007: Tables with unused indexes
- T008: Tables with foreign key type mismatches
- T009: Tables with no roles granted
- T010: Tables using reserved keywords
- T011: Tables with uppercase names/columns
- T012: Tables with sensitive columns

---

### perform_schema_check([output_file])

Executes all enabled schema rules (S-series) for schema-level analysis.

**Syntax:**
```sql
SELECT pglinter.perform_schema_check([output_file text]);
```

**Parameters:**
- `output_file` (optional): Path to save SARIF results

**Returns:**
- When `output_file` specified: Success message
- When no file specified: Table with rule results

**Examples:**
```sql
-- Analyze schemas
SELECT * FROM pglinter.perform_schema_check();

-- Save schema analysis
SELECT pglinter.perform_schema_check('/tmp/schema_analysis.sarif');
```

**Rule Coverage:**
- S001: Schemas without proper privileges
- S002: Schemas with public privileges

---

## Rule Management Functions

### show_rules()

Displays all available rules with their current status.

**Syntax:**
```sql
SELECT * FROM pglinter.show_rules();
```

**Returns:**
Table with columns:
- `rule_code`: Rule identifier (e.g., 'B001')
- `description`: Brief rule description
- `enabled`: Whether rule is currently enabled
- `scope`: Rule category (Base, Cluster, Table, Schema)

**Example:**
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

**Syntax:**
```sql
SELECT pglinter.is_rule_enabled(rule_code text);
```

**Parameters:**
- `rule_code`: Rule identifier (e.g., 'B001')

**Returns:**
- `boolean`: true if enabled, false if disabled, NULL if rule doesn't exist

**Examples:**
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

**Syntax:**
```sql
SELECT pglinter.enable_rule(rule_code text);
```

**Parameters:**
- `rule_code`: Rule identifier to enable

**Returns:**
- `text`: Success or error message

**Examples:**
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

**Syntax:**
```sql
SELECT pglinter.disable_rule(rule_code text);
```

**Parameters:**
- `rule_code`: Rule identifier to disable

**Returns:**
- `text`: Success or error message

**Examples:**
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

**Syntax:**
```sql
SELECT pglinter.explain_rule(rule_code text);
```

**Parameters:**
- `rule_code`: Rule identifier to explain

**Returns:**
- `text`: Detailed rule explanation with description and numbered fix recommendations

**Examples:**
```sql
-- Get explanation for B002
SELECT pglinter.explain_rule('B002');

-- Get explanations for all rules
SELECT rule_code, pglinter.explain_rule(rule_code) as explanation
FROM pglinter.show_rules()
ORDER BY rule_code;
```

**Sample Output:**
```
Rule B002: Redundant indexes

Description: Detects redundant indexes that have identical column sets

How to fix:
1. Identify redundant indexes using pg_stat_user_indexes
2. Drop unnecessary duplicate indexes
3. Keep the most appropriately named index
4. Consider if indexes serve different purposes (unique vs non-unique)
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

2. **Scheduled Analysis**
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

For more usage examples, see the [How-To Guides](../how-to/) and [Tutorials](../tutorials/).
