# How-To Guides

Practical guides for common pglinter scenarios.

# get_violations()

## Purpose

The `get_violations()` function in pglinter is designed to collect and return all detected violations for enabled rules in the PostgreSQL database. It provides a programmatic way to retrieve which rules have violations and the specific database objects affected, supporting deeper analysis and integration with reporting tools.

## 💻 Usage

After installation, enable the extension in your PostgreSQL database:

```sql
-- Connect to your database
\c your_database

-- Create the extension
CREATE EXTENSION pglinter;

-- Get all violations
SELECT * FROM pglinter.get_violations();

-- Filter violations for a specific rule
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B001';  -- Tables without primary keys
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B002';  -- Redundant indexes

-- To get object name
SELECT
  rule_code,
  (pg_identify_object(classid, objid, objsubid)).type,
  (pg_identify_object(classid, objid, objsubid)).schema,
  (pg_identify_object(classid, objid, objsubid)).name,
  (pg_identify_object(classid, objid, objsubid)).identity
  from pglinter.get_violations()

```

### 📋 Available Rules

- **B00**: Base database rules (primary keys, indexes, schemas, etc.)
- **C00**: Cluster security rules
- **S00**: Schema rules

### How it works

  1. Queries the `pglinter.rules` table for all enabled rules.
  2. For each rule, calls `get_violations_for_rule()` to fetch all violation locations.
  3. Returns a vector of tuples: each tuple contains the rule code and a vector of violation locations.

#### Return Value

  get_violations() returns oid, not the name. To get readable values, you can use

```sql
SELECT
    (pg_identify_object(classid, objid, objsubid)).type AS object_type,
    (pg_identify_object(classid, objid, objsubid)).schema AS object_schema,
    (pg_identify_object(classid, objid, objsubid)).name AS object_name,
    (pg_identify_object(classid, objid, objsubid)).identity AS object_identity
FROM pglinter.get_violations()
```

- On success: `Ok(Vec<(rule_code, Vec<(classid, objid, objsubid)>)>)`
- On error: `Err(String)` with a descriptive error message

## Typical Use Cases

- Automated reporting of rule violations
- Integration with SARIF or other static analysis formats
- Custom dashboards or alerting for database health
- Regression testing and rule validation

## Notes

- Only enabled rules are checked.
- Handles errors gracefully and logs issues per rule.
- Designed for extensibility and integration with other pglinter features.
