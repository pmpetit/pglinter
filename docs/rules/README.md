# Rule Reference

Complete reference for all PG Linter rules, organized by category with detailed descriptions, examples, and remediation guidance based on the actual rules defined in `sql/rules.sql`.

## Rule Categories

PG Linter organizes analysis rules into three main categories:

- **[B-series](#base-rules-b-series)**: Database-wide checks including tables, indexes, constraints, and general database analysis
- **[C-series](#cluster-rules-c-series)**: Cluster configuration checks
- **[S-series](#schema-rules-s-series)**: Schema-level checks

## Base Rules (B-series)

Database-wide checks that analyze overall database health and structure.

### B001: Tables Without Primary Keys

**Rule Code**: B001
**Name**: HowManyTableWithoutPrimaryKey
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of tables without primary key.

**Message Template**: `{0}/{1} table(s) without primary key exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Primary keys ensure data uniqueness and integrity
- Required for logical replication
- Improves query performance and indexing strategies
- Essential for proper foreign key relationships

**How to Fix**:

- Create a primary key or change warning/error threshold

**SQL Example**:

```sql
-- Add a surrogate primary key
ALTER TABLE users ADD COLUMN id SERIAL PRIMARY KEY;

-- Add a composite primary key
ALTER TABLE user_roles ADD PRIMARY KEY (user_id, role_id);
```

---

### B002: Redundant Indexes

**Rule Code**: B002
**Name**: HowManyRedudantIndex
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of redundant index vs nb index.

**Message Template**: `{0}/{1} redundant(s) index exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Redundant indexes waste storage space
- Slow down write operations (INSERT/UPDATE/DELETE)
- Increase maintenance overhead
- Can confuse query planner

**How to Fix**:

- Remove duplicated index or check if a constraint does not create a redundant index, or change warning/error threshold

**SQL Example**:

```sql
-- Find potentially redundant indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0;

-- Drop redundant index
DROP INDEX idx_users_email_duplicate;
```

---

### B003: Tables Without Index on Foreign Keys

**Rule Code**: B003
**Name**: HowManyTableWithoutIndexOnFk
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of tables without index on foreign key.

**Message Template**: `{0}/{1} table(s) without index on foreign key exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Foreign key columns without indexes cause slow JOIN operations
- Can lead to lock contention during parent table modifications
- Severely impacts referential integrity check performance

**How to Fix**:

- Create a index on foreign key or change warning/error threshold

**SQL Example**:

```sql
-- Add index to foreign key column
CREATE INDEX idx_orders_customer_id ON orders (customer_id);

-- Composite index for multi-column foreign keys
CREATE INDEX idx_order_items_order_product ON order_items (order_id, product_id);
```

---

### B004: Unused Indexes

**Rule Code**: B004
**Name**: HowManyUnusedIndex
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of unused index vs nb index (base on pg_stat_user_indexes, indexes associated to unique constraints are discard.)

**Message Template**: `{0}/{1} unused index exceed the {2} threshold: {3}%`

**Why This Matters**:

- Unused indexes waste storage space
- Slow down write operations
- Consume maintenance resources without providing benefit

**How to Fix**:

- Remove unused index or change warning/error threshold

**SQL Example**:

```sql
-- Find unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0;

-- Drop unused index
DROP INDEX idx_unused_column;
```

---

### B005: Objects With Uppercase Names

**Rule Code**: B005
**Name**: HowManyObjectsWithUppercase
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of objects with uppercase in name or in columns.

**Message Template**: `{0}/{1} object(s) using uppercase for name or columns exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Inconsistent with PostgreSQL naming conventions
- Requires quoting in SQL statements
- Can cause portability issues between databases

**How to Fix**:

- Do not use uppercase for any database objects

**SQL Example**:

```sql
-- Rename table to lowercase
ALTER TABLE "UserProfiles" RENAME TO user_profiles;

-- Rename column to lowercase
ALTER TABLE users RENAME COLUMN "FirstName" TO first_name;
```

---

### B006: Tables Never Selected

**Rule Code**: B006
**Name**: HowManyTablesNeverSelected
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of table(s) that has never been selected.

**Message Template**: `{0}/{1} table(s) are never selected the {2} threshold: {3}%.`

**Why This Matters**:

- Indicates potentially unused or forgotten tables
- Such tables consume storage and maintenance resources
- May contain stale or obsolete data

**How to Fix**:

- Is it necessary to update/delete/insert rows in table(s) that are never selected ?

**SQL Example**:

```sql
-- Check table usage statistics
SELECT schemaname, tablename, seq_scan, idx_scan, n_tup_ins, n_tup_upd
FROM pg_stat_user_tables
WHERE seq_scan = 0 AND idx_scan = 0;
```

---

### B007: Tables With Foreign Keys Outside Schema

**Rule Code**: B007
**Name**: HowManyTablesWithFkOutsideSchema
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of tables with foreign keys outside their schema.

**Message Template**: `{0}/{1} table(s) with foreign keys outside schema exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Can complicate schema migrations and maintenance
- May indicate poor schema organization
- Can create unwanted dependencies between schemas

**How to Fix**:

- Consider restructuring schema design to keep related tables in same schema
- Ask a DBA

**SQL Example**:

```sql
-- Check for foreign keys crossing schema boundaries
SELECT
    tc.table_schema,
    tc.table_name,
    tc.constraint_name,
    ccu.table_schema AS referenced_schema,
    ccu.table_name AS referenced_table
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema != ccu.table_schema;
```

---

### B008: Foreign Key Type Mismatches

**Rule Code**: B008
**Name**: HowManyTablesWithFkMismatch
**Severity**: Warning at 1%, Error at 80%
**Scope**: BASE

**Description**: Count number of tables with foreign keys that do not match the key reference type.

**Message Template**: `{0}/{1} table(s) with foreign key mismatch exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Type mismatches between foreign keys and referenced columns can cause performance issues
- May lead to unexpected behavior in joins and constraints
- Can prevent proper use of indexes on foreign key columns
- Indicates potential data modeling issues

**How to Fix**:

- Consider column type adjustments to ensure foreign key matches referenced key type
- Ask a DBA

**SQL Example**:

```sql
-- Find foreign key type mismatches
SELECT
    tc.table_schema,
    tc.table_name,
    tc.constraint_name,
    kcu.column_name,
    col1.data_type AS fk_column_type,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column,
    col2.data_type AS referenced_column_type
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
JOIN information_schema.columns col1 ON kcu.table_name = col1.table_name AND kcu.column_name = col1.column_name
JOIN information_schema.columns col2 ON ccu.table_name = col2.table_name AND ccu.column_name = col2.column_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND col1.data_type != col2.data_type;
```

---

### B009: Tables Using Same Trigger Function

**Rule Code**: B009
**Name**: HowManyTablesWithSameTrigger
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of tables using the same trigger vs nb table with their own triggers.

**Message Template**: `{0}/{1} table(s) using the same trigger function exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Sharing trigger functions across tables adds complexity
- Makes debugging and maintenance more difficult
- Can create unexpected side effects when modifying trigger logic
- Reduces code readability and maintainability

**How to Fix**:

- For more readability and other considerations use one trigger function per table
- Sharing the same trigger function add more complexity

**SQL Example**:

```sql
-- Find tables sharing trigger functions
SELECT
    trigger_function,
    array_agg(DISTINCT table_name) AS tables_using_function,
    count(DISTINCT table_name) AS table_count
FROM (
    SELECT
        event_object_table AS table_name,
        substring(action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function
    FROM information_schema.triggers
    WHERE trigger_schema NOT IN ('information_schema', 'pg_catalog')
) t
GROUP BY trigger_function
HAVING count(DISTINCT table_name) > 1;
```

---

### B010: Objects Using Reserved Keywords

**Rule Code**: B010
**Name**: HowManyTablesWithReservedKeywords
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Count number of database objects using reserved keywords in their names.

**Message Template**: `{0}/{1} object(s) using reserved keywords exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Reserved keywords require quoting in SQL statements
- Can cause SQL syntax errors and parsing issues
- Makes code less portable between database systems
- Creates maintenance difficulties and confusion

**How to Fix**:

- Rename database objects to avoid using reserved keywords
- Using reserved keywords can lead to SQL syntax errors and maintenance difficulties

**SQL Example**:

```sql
-- Check for objects using reserved keywords (example with 'user' table)
SELECT tablename
FROM pg_tables
WHERE tablename IN ('user', 'table', 'select', 'from', 'where', 'order', 'group');

-- Rename objects that use reserved keywords
ALTER TABLE "user" RENAME TO app_user;
ALTER TABLE "order" RENAME TO customer_order;
```

---

### B011: Multiple Table Owners in Schema

**Rule Code**: B011
**Name**: SeveralTableOwnerInSchema
**Severity**: Warning at 1%, Error at 80%
**Scope**: BASE

**Description**: In a schema there are several tables owned by different owners.

**Message Template**: `{0}/{1} schemas have tables owned by different owners. Exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Inconsistent ownership makes maintenance difficult
- Can create permission and access control issues
- Complicates backup and restore operations
- Makes schema management more complex

**How to Fix**:

- Change table owners to the same functional role

**SQL Example**:

```sql
-- Find schemas with mixed table ownership
SELECT
    schemaname,
    array_agg(DISTINCT tableowner) AS owners,
    count(DISTINCT tableowner) AS owner_count
FROM pg_tables
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
GROUP BY schemaname
HAVING count(DISTINCT tableowner) > 1;

-- Standardize table ownership within a schema
ALTER TABLE schema_name.table1 OWNER TO schema_owner_role;
ALTER TABLE schema_name.table2 OWNER TO schema_owner_role;
```

---

## Schema Rules (S-series)

Schema-level checks for functional namespace.

### S001: Schema Without Default Role Grants

**Rule Code**: S001
**Name**: SchemaWithDefaultRoleNotGranted
**Severity**: Warning at 1, Error at 1
**Scope**: SCHEMA

**Description**: The schema has no default role. Means that future table will not be granted through a role. So you will have to re-execute grants on it.

**Message Template**: `No default role grantee on schema {0}.{1}. It means that each time a table is created, you must grant it to roles.`

**Why This Matters**:

- Future tables won't automatically inherit proper permissions
- Requires manual grant management for each new table
- Can lead to access control gaps

**How to Fix**:

- Add a default privilege: `ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> FOR USER <schema's owner>`

**SQL Example**:

```sql
-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA myschema
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO myschema_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA myschema
GRANT SELECT ON TABLES TO myschema_ro;
```

---

### S002: Environment-Named Schemas

**Rule Code**: S002
**Name**: SchemaPrefixedOrSuffixedWithEnvt
**Severity**: Warning at 1, Error at 1
**Scope**: SCHEMA

**Description**: The schema is prefixed with one of staging,stg,preprod,prod,sandbox,sbox string. Means that when you refresh your preprod, staging environments from production, you have to rename the target schema from prod_ to stg_ or something like. It is possible, but it is never easy.

**Message Template**: `You should not prefix or suffix the schema name with {0}. You may have difficulties when refreshing environments. Prefer prefix or suffix the database name.`

**Why This Matters**:

- Environment-specific schemas complicate environment management
- Makes database refreshes and migrations more complex
- Can lead to deployment and configuration issues

**How to Fix**:

- Keep the same schema name across environments. Prefer prefix or suffix the database name

**Example**:

```sql
-- Instead of: myapp_prod.users, myapp_stg.users
-- Use: myapp.users in databases: myapp_prod, myapp_stg
```

---

### S003: Unsecured Public Schema Access

**Rule Code**: S003
**Name**: UnsecuredPublicSchema
**Severity**: Warning at 1%, Error at 80%
**Scope**: SCHEMA

**Description**: Only authorized users should be allowed to create objects.

**Message Template**: `{0}/{1} schemas are unsecured, schemas where all users can create objects in, exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Allows any user to create objects in schemas
- Can lead to security vulnerabilities and unauthorized access
- Makes access control management difficult
- May result in unexpected objects being created by unprivileged users

**How to Fix**:

- `REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC`

**SQL Example**:

```sql
-- Check which schemas allow public creation
SELECT nspname
FROM pg_namespace
WHERE HAS_SCHEMA_PRIVILEGE('public', nspname, 'CREATE')
AND nspname NOT IN ('information_schema', 'pg_catalog');

-- Secure a schema by revoking public creation privileges
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA myschema FROM PUBLIC;

-- Grant creation privileges to specific roles only
GRANT CREATE ON SCHEMA myschema TO app_role;
```

---

### S004: Schema Owned by Internal/System Roles

**Rule Code**: S004
**Name**: OwnerSchemaIsInternalRole
**Severity**: Warning at 20%, Error at 80%
**Scope**: SCHEMA

**Description**: Owner of schema should not be any internal pg roles, or owner is a superuser (not sure it is necesary).

**Message Template**: `{0}/{1} schemas are owned by internal roles or superuser. Exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Schemas owned by system roles or superusers can create security risks
- Makes proper role separation and access control difficult
- Can lead to privilege escalation issues
- Complicates backup and restore operations

**How to Fix**:

- Change schema owner to a functional role

**SQL Example**:

```sql
-- Find schemas owned by system roles or superusers
SELECT
    n.nspname AS schema_name,
    r.rolname AS owner_name,
    r.rolsuper AS is_superuser
FROM pg_namespace n
JOIN pg_roles r ON n.nspowner = r.oid
WHERE (
    r.rolsuper IS TRUE
    OR r.rolname LIKE 'pg_%'
    OR r.rolname = 'postgres'
)
AND n.nspname NOT IN ('information_schema', 'pg_catalog');

-- Change schema ownership to a functional role
ALTER SCHEMA myschema OWNER TO app_owner_role;
```

---

### S005: Schema and Table Owner Mismatch

**Rule Code**: S005
**Name**: SchemaOwnerDoNotMatchTableOwner
**Severity**: Warning at 20%, Error at 80%
**Scope**: SCHEMA

**Description**: The schema owner and tables in the schema do not match.

**Message Template**: `{0}/{1} in the same schema, tables have different owners. They should be the same. Exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Inconsistent ownership complicates maintenance and permissions
- Can create access control and security issues
- Makes backup, restore, and migration operations more complex
- Reduces administrative efficiency and clarity

**How to Fix**:

- For maintenance facilities, schema and tables owners should be the same

**SQL Example**:

```sql
-- Find schemas where table owners don't match schema owner
SELECT
    n.nspname AS schema_name,
    r_schema.rolname AS schema_owner,
    c.relname AS table_name,
    r_table.rolname AS table_owner
FROM pg_namespace n
JOIN pg_class c ON c.relnamespace = n.oid
JOIN pg_roles r_schema ON n.nspowner = r_schema.oid
JOIN pg_roles r_table ON c.relowner = r_table.oid
WHERE
    c.relkind = 'r'  -- regular tables only
    AND n.nspowner <> c.relowner  -- owners are different
    AND n.nspname NOT IN ('information_schema', 'pg_catalog');

-- Align table ownership with schema ownership
ALTER TABLE myschema.table1 OWNER TO schema_owner_role;
ALTER TABLE myschema.table2 OWNER TO schema_owner_role;

-- Or change all tables in a schema at once
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'myschema'
    LOOP
        EXECUTE 'ALTER TABLE myschema.' || rec.tablename || ' OWNER TO schema_owner_role';
    END LOOP;
END $$;
```

---

## Rule Management

### Viewing Rules

```sql
-- Show all available rules
SELECT * FROM pglinter.show_rules();

-- Show only enabled rules
SELECT * FROM pglinter.show_rules() WHERE enable = true;

-- Show rules by category
SELECT * FROM pglinter.show_rules() WHERE code LIKE 'B%';

-- Get rule details
SELECT pglinter.explain_rule('B001');
```

### Enabling/Disabling Rules

```sql
-- Disable a specific rule
SELECT pglinter.disable_rule('B001');

-- Enable a specific rule
SELECT pglinter.enable_rule('B001');

-- Disable all rules
SELECT pglinter.disable_all_rules();

-- Enable all rules
SELECT pglinter.enable_all_rules();

-- Check if rule is enabled
SELECT pglinter.is_rule_enabled('B001');
```

### Rule Configuration

```sql
-- Check current rule settings
SELECT code, enable, warning_level, error_level, scope
FROM pglinter.rules
WHERE code = 'B001';

-- Update rule thresholds
SELECT pglinter.update_rule_levels('B001', 30, 70);

-- Get rule threshold levels
SELECT pglinter.get_rule_levels('B001');

-- Show rule queries (for debugging)
SELECT pglinter.show_rule_queries('B001');
```

### Rule Execution

```sql
-- Run all enabled rules
SELECT pglinter.check();

-- Run a specific rule only
SELECT pglinter.check_rule('B001');
SELECT pglinter.check_rule('C002');

-- Generate SARIF output
SELECT pglinter.check('/tmp/results.sarif');
SELECT pglinter.check_rule('B001', '/tmp/b001_results.sarif');
```

---

## Rule Import/Export

### YAML Configuration

Rules can be imported and exported in YAML format for version control and configuration management:

```sql
-- Export current rules to YAML
SELECT pglinter.export_rules_to_yaml();

-- Import rules from YAML content
SELECT pglinter.import_rules_from_yaml('
metadata:
  export_timestamp: "2024-01-01T00:00:00Z"
  total_rules: 25
  format_version: "1.0"
rules:
  - id: 1
    name: "HowManyTableWithoutPrimaryKey"
    code: "B001"
    enable: true
    warning_level: 20
    error_level: 80
    scope: "BASE"
    description: "Count number of tables without primary key"
    message: "{0}/{1} table(s) without primary key exceed the {2} threshold: {3}%."
    fixes:
      - "create a primary key or change warning/error threshold"
');

-- Import rules from YAML file
SELECT pglinter.import_rules_from_file('/path/to/rules.yaml');
```

---

## Best Practices

### Rule Selection by Environment

**Development Environment**:

- Enable all rules to catch issues early
- Use relaxed thresholds (higher warning/error levels)
- Focus on structural issues (B001, T001, T008)

**Staging Environment**:

- Enable all rules with moderate thresholds
- Focus on performance rules (B004, T004, B002)
- Test rule configurations before production

**Production Environment**:

- Enable critical rules with sensitive thresholds
- Monitor continuously for performance degradation
- Focus on security and performance rules

### Rule Prioritization

**High Priority** (Fix immediately):

- T007: Foreign key type mismatches
- C002: Insecure authentication methods
- T001: Missing primary keys on critical tables

**Medium Priority** (Plan fixes):

- B001: Missing primary keys (database-wide)
- B004: Unused indexes
- B003, T003: Missing foreign key indexes

**Low Priority** (Improve over time):

- B005, B006: Naming conventions
- T009: Reserved keyword usage
- S002: Environment-named schemas

### Integration Strategies

**CI/CD Integration**:

```bash
# Run all checks as part of deployment pipeline
psql -c "SELECT pglinter.check('/tmp/results.sarif')"

# Run specific critical rules only
psql -c "SELECT pglinter.check_rule('B001', '/tmp/primary_keys.sarif')"
psql -c "SELECT pglinter.check_rule('C002', '/tmp/security.sarif')"
```

**Regular Monitoring**:

```sql
-- Schedule weekly reports
SELECT pglinter.check();
```

**Custom Rule Sets**:

```sql
-- Create environment-specific rule sets
-- Disable noisy rules in development
SELECT pglinter.disable_rule('B004');
SELECT pglinter.disable_rule('B005');
```

---

## SARIF Output Integration

PG Linter supports SARIF (Static Analysis Results Interchange Format) output for integration with modern development tools:

```sql
-- Generate SARIF report
SELECT pglinter.check('/tmp/analysis.sarif');
```

SARIF files can be consumed by:

- GitHub Actions (Code Scanning)
- GitLab CI/CD
- Azure DevOps
- Various IDEs and security tools

---

## Troubleshooting

### Common Issues

**Rule not triggering as expected**:

1. Check if rule is enabled: `SELECT enable FROM pglinter.rules WHERE code = 'B001';`
2. Verify thresholds are appropriate for your data
3. Check if rule queries are returning expected results: `SELECT pglinter.show_rule_queries('B001');`

**Performance impact**:

1. Rules analyze system catalogs and statistics
2. Run during maintenance windows for large databases
3. Consider disabling resource-intensive rules if needed
4. Monitor execution time with `\timing` in psql

**False positives**:

1. Adjust thresholds for environment-specific needs: `SELECT pglinter.update_rule_levels('B001', 30, 70);`
2. Disable rules that don't apply to your use case
3. Document exceptions and reasoning

**T010 rule disabled**:

1. Install the `anon` extension: `CREATE EXTENSION IF NOT EXISTS anon CASCADE;`
2. Enable the rule: `SELECT pglinter.enable_rule('T010');`

### Getting Help

- Review rule descriptions and examples in this documentation
- Check the source queries: `SELECT q1, q2 FROM pglinter.rules WHERE code = 'B001';`
- Use `pglinter.explain_rule('B001')` for detailed rule information
- Report issues and contribute improvements on GitHub

---

This documentation covers all currently implemented rules based on the actual `sql/rules.sql` definitions. New rules and features are added regularly - check the Functions Reference for the latest capabilities.
