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

### B005: Unsecured Public Schema

**Rule Code**: B005
**Name**: UnsecuredPublicSchema
**Severity**: Warning at 20%, Error at 80%
**Scope**: BASE

**Description**: Only authorized users should be allowed to create objects.

**Message Template**: `{0}/{1} schemas are unsecured, schemas where all users can create objects in, exceed the {2} threshold: {3}%.`

**Why This Matters**:

- Allows any user to create objects in schemas
- Can lead to security vulnerabilities
- Makes access control management difficult

**How to Fix**:

- `REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC`

**SQL Example**:

```sql
-- Secure a schema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO specific_role;
```

---

### B006: Objects With Uppercase Names

**Rule Code**: B006
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

### B007: Tables Never Selected

**Rule Code**: B007
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

### B008: Tables With Foreign Keys Outside Schema

**Rule Code**: B008
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

---

## Cluster Rules (C-series)

PostgreSQL cluster configuration checks for system-level settings.

### C002: Insecure Authentication Methods

**Rule Code**: C002
**Name**: PgHbaEntriesWithMethodTrustOrPasswordShouldNotExists
**Severity**: Warning at 20%, Error at 80%
**Scope**: CLUSTER

**Description**: This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.

**Message Template**: `{0} entries in pg_hba.conf with trust or password authentication method exceed the warning threshold: {1}.`

**Why This Matters**:

- "trust" and "password" methods are insecure
- Can lead to unauthorized database access
- Passwords transmitted in plain text with "password" method

**How to Fix**:

- Change trust or password method in pg_hba.conf

**SQL Example**:

```sql
-- Check current authentication methods
SELECT * FROM pg_hba_file_rules WHERE auth_method IN ('trust', 'password');
```

**Configuration Fix**:

```
# Replace in pg_hba.conf:
# host    all    all    0.0.0.0/0    trust
# With:
host    all    all    0.0.0.0/0    scram-sha-256
```

---

### C003: MD5 Password Encryption

**Rule Code**: C003
**Name**: PasswordEncryptionIsMd5
**Severity**: Warning at 20%, Error at 80%
**Scope**: CLUSTER

**Description**: This configuration is not secure anymore and will prevent an upgrade to Postgres 18. Warning, you will need to reset all passwords after this is changed to scram-sha-256.

**Message Template**: ``

**Why This Matters**:

- MD5 password encryption is deprecated and insecure
- PostgreSQL 18+ will not support MD5 password encryption
- MD5 hashing is cryptographically weak and vulnerable to attacks
- Prevents database upgrades to newer PostgreSQL versions
- Security compliance requirements often prohibit MD5

**How to Fix**:

1. **Change password_encryption parameter to scram-sha-256**
2. **Reset all existing user passwords** (required after parameter change)
3. **Update application connection strings** if needed
4. **Test all connections** thoroughly before deploying

**SQL Example**:

```sql
-- Check current password encryption setting
SHOW password_encryption;

-- Change to SCRAM-SHA-256 (requires superuser)
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();

-- Reset user passwords (each user password must be reset)
ALTER USER myuser PASSWORD 'new_secure_password';

-- Verify the change
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolcanlogin = true;
```

**Configuration Steps**:

```sql
-- 1. Change the global setting
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();

-- 2. Reset all user passwords
-- (This must be done for each user individually)
ALTER USER app_user PASSWORD 'reset_password_123';
ALTER USER readonly_user PASSWORD 'reset_password_456';

-- 3. Update pg_hba.conf if using md5 auth method
-- Change: host all all 0.0.0.0/0 md5
-- To:     host all all 0.0.0.0/0 scram-sha-256
```

**⚠️ Important Warnings**:

- **All existing passwords become invalid** after changing password_encryption
- **Applications will fail to connect** until passwords are reset
- **Plan maintenance window** for this change
- **Test thoroughly** in non-production environment first
- **Update application configurations** to use new auth method

---

## Schema Rules (S-series)

Schema-level checks for organization and security.

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
-- Run all rules
SELECT pglinter.check_all();

-- Run specific rule categories
SELECT pglinter.perform_base_check();
SELECT pglinter.perform_cluster_check();
SELECT pglinter.perform_schema_check();
SELECT pglinter.perform_table_check();

-- Generate SARIF output
SELECT pglinter.perform_base_check('/tmp/base_results.sarif');
SELECT pglinter.check_all('/tmp/complete_results.sarif');
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
# Run checks as part of deployment pipeline
psql -c "SELECT pglinter.check_all('/tmp/results.sarif')"
```

**Regular Monitoring**:

```sql
-- Schedule weekly reports
SELECT pglinter.check_all();
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
SELECT pglinter.perform_base_check('/tmp/analysis.sarif');
SELECT pglinter.perform_table_check('/tmp/table_analysis.sarif');
SELECT pglinter.check_all('/tmp/complete_analysis.sarif');
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
