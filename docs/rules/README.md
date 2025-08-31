# Rule Reference

Complete reference for all PG Linter rules, organized by category with detailed descriptions, examples, and remediation guidance.

## Rule Categories

PG Linter organizes analysis rules into four main categories:

- **[B-series](#base-rules-b-series)**: Database-wide checks
- **[C-series](#cluster-rules-c-series)**: Cluster configuration checks
- **[T-series](#table-rules-t-series)**: Individual table checks
- **[S-series](#schema-rules-s-series)**: Schema-level checks

## Base Rules (B-series)

Database-wide checks that analyze overall database health and structure.

### B001: Tables Without Primary Keys

**Description**: Detects when too many tables in the database lack primary keys.

**Severity**: Warning

**Default Threshold**: 20% of tables without primary keys

**Why This Matters**:

- Primary keys ensure data uniqueness and integrity
- Required for logical replication
- Improves query performance and indexing strategies
- Essential for proper foreign key relationships

**Example Output**:

```text
5 tables without primary key exceed the warning threshold: 20%
```

**How to Fix**:

1. Add primary keys to tables that logically should have them
2. Use surrogate keys (SERIAL/BIGSERIAL) when natural keys don't exist
3. Consider composite primary keys for junction tables
4. For logging tables, evaluate if primary keys are necessary

**SQL Example**:

```sql
-- Add a surrogate primary key
ALTER TABLE users ADD COLUMN id SERIAL PRIMARY KEY;

-- Add a composite primary key
ALTER TABLE user_roles ADD PRIMARY KEY (user_id, role_id);
```

---

### B002: Redundant Indexes

**Description**: Identifies indexes with identical column sets that may be redundant.

**Severity**: Warning

**Why This Matters**:

- Redundant indexes waste storage space
- Slow down write operations (INSERT/UPDATE/DELETE)
- Increase maintenance overhead
- Can confuse query planner

**Example Output**:

```text
Found potential redundant indexes in the database
```

**How to Fix**:

1. Identify redundant indexes using pg_stat_user_indexes
2. Drop unnecessary duplicate indexes
3. Keep the most appropriately named index
4. Consider if indexes serve different purposes (unique vs non-unique)

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

### B003: Foreign Keys Without Indexes

**Description**: Detects foreign key columns that lack supporting indexes.

**Severity**: Warning

**Why This Matters**:

- Foreign key columns without indexes cause slow JOIN operations
- Can lead to lock contention during parent table modifications
- Severely impacts referential integrity check performance

**Example Output**:

```text
Found 3 foreign key columns without indexes
```

**How to Fix**:

1. Add indexes to all foreign key columns
2. Consider composite indexes if foreign keys are often queried together
3. Use partial indexes for frequently filtered foreign keys

**SQL Example**:

```sql
-- Add index to foreign key column
CREATE INDEX idx_orders_customer_id ON orders (customer_id);

-- Composite index for multi-column foreign keys
CREATE INDEX idx_order_items_order_product ON order_items (order_id, product_id);
```

---

### B004: Unused Indexes

**Description**: Identifies indexes that are never used by queries.

**Severity**: Warning

**Why This Matters**:

- Unused indexes consume storage space unnecessarily
- Slow down write operations
- Waste maintenance resources during VACUUM and updates

**Example Output**:

```text
Found 2 potentially unused indexes
```

**How to Fix**:

1. Analyze pg_stat_user_indexes to confirm usage patterns
2. Drop genuinely unused indexes
3. Consider keeping indexes for rare but critical queries
4. Monitor after removal to ensure no performance regression

**SQL Example**:

```sql
-- Check index usage statistics
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0;

-- Drop unused index after verification
DROP INDEX idx_rarely_used_column;
```

---

### B005: Unsecured Public Schema

**Description**: Checks for security issues with the public schema.

**Severity**: Warning

**Why This Matters**:

- Public schema is accessible to all users by default
- Can lead to privilege escalation vulnerabilities
- May expose sensitive data or functions

**Example Output**:

```text
Public schema security issues detected
```

**How to Fix**:

1. Revoke CREATE privileges from public schema for non-superusers
2. Move application objects to dedicated schemas
3. Grant specific privileges instead of using public access

**SQL Example**:

```sql
-- Secure the public schema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE mydb FROM PUBLIC;

-- Create application-specific schema
CREATE SCHEMA app;
GRANT USAGE ON SCHEMA app TO app_user;
```

---

### B006: Uppercase Names/Columns

**Description**: Detects database objects using uppercase letters in names.

**Severity**: Warning

**Why This Matters**:

- Inconsistent with PostgreSQL naming conventions
- Requires quoting in SQL statements
- Can cause portability issues between databases
- Makes code harder to read and maintain

**Example Output**:

```text
Found 4 database objects with uppercase letters
```

**How to Fix**:

1. Use lowercase naming conventions for all database objects
2. Use underscores to separate words instead of camelCase
3. Plan migration strategy for existing uppercase objects

**SQL Example**:

```sql
-- Rename table to lowercase
ALTER TABLE "UserProfiles" RENAME TO user_profiles;

-- Rename column to lowercase
ALTER TABLE users RENAME COLUMN "FirstName" TO first_name;
```

---

## Cluster Rules (C-series)

PostgreSQL cluster configuration checks for system-level settings.

### C001: Memory Configuration Issues

**Description**: Checks if max_connections × work_mem exceeds available system RAM.

**Severity**: Warning/Error

**Why This Matters**:

- Can lead to out-of-memory conditions
- May cause system instability or crashes
- Indicates misconfigured PostgreSQL parameters

**Example Output**:

```text
work_mem * max_connections is bigger than available RAM
```

**How to Fix**:

1. Reduce max_connections if too high for your workload
2. Decrease work_mem if individual queries don't need large sort areas
3. Increase system RAM if budget allows
4. Consider connection pooling to reduce actual concurrent connections

**Configuration Example**:

```sql
-- Check current settings
SHOW max_connections;
SHOW work_mem;

-- Adjust parameters (requires restart)
-- In postgresql.conf:
-- max_connections = 100
-- work_mem = 4MB
```

---

### C002: Insecure Authentication Methods

**Description**: Detects insecure authentication methods in pg_hba.conf.

**Severity**: Warning/Error

**Why This Matters**:

- "trust" and "password" methods are insecure
- Can lead to unauthorized database access
- Passwords transmitted in plain text with "password" method

**Example Output**:

```text
2 entries in pg_hba.conf with trust or password authentication method exceed the warning threshold
```

**How to Fix**:

1. Replace "trust" with "md5" or "scram-sha-256"
2. Replace "password" with "md5" or "scram-sha-256"
3. Use certificate-based authentication for highest security
4. Restrict access to trusted IP addresses only

**Configuration Example**:

```text
# Instead of:
# host    all    all    0.0.0.0/0    trust

# Use:
host    all    all    192.168.1.0/24    scram-sha-256
```

---

## Table Rules (T-series)

Individual table-specific checks for data structure and performance.

### T001: Individual Tables Without Primary Keys

**Description**: Identifies specific tables that lack primary keys.

**Severity**: Warning

**Why This Matters**:

- Table-specific version of B001
- Provides detailed information about which tables need attention
- Essential for data integrity and replication

**Example Output**:

```text
No primary key on table public.logs
```

**How to Fix**:

- See B001 remediation guidance
- Focus on the specific tables identified

---

### T002: Tables Without Any Indexes

**Description**: Identifies tables that have no indexes at all.

**Severity**: Warning

**Why This Matters**:

- Tables without indexes force full table scans
- Severely impacts query performance
- May indicate incomplete schema design

**Example Output**:

```text
Found 2 tables without any index: public.logs, public.temp_data
```

**How to Fix**:

1. Add primary key (which creates an index automatically)
2. Create indexes on frequently queried columns
3. Analyze query patterns to determine optimal index strategy

**SQL Example**:

```sql
-- Add primary key (creates index)
ALTER TABLE logs ADD COLUMN id SERIAL PRIMARY KEY;

-- Add index on frequently queried column
CREATE INDEX idx_logs_timestamp ON logs (created_at);
```

---

### T003: Tables With Redundant Indexes

**Description**: Table-specific detection of redundant indexes.

**Severity**: Warning

**Why This Matters**:

- Same as B002 but provides table-level detail
- Helps prioritize which tables to optimize first

**Example Output**:

```text
Found 2 tables with redundant indexes: public.users, public.orders
```

**How to Fix**:

- See B002 remediation guidance
- Focus on the specific tables identified

---

### T004: Foreign Keys Without Indexes

**Description**: Identifies specific foreign keys that lack supporting indexes.

**Severity**: Warning

**Why This Matters**:

- Table-specific version of B003
- Provides exact foreign key constraints needing indexes

**Example Output**:

```text
Found 3 foreign keys without indexes: public.orders (FK: fk_customer), public.items (FK: fk_order)
```

**How to Fix**:

- See B003 remediation guidance
- Focus on the specific foreign keys identified

---

### T005: High Sequential Scan Usage

**Description**: Detects tables with high sequential scan ratios indicating potential missing indexes.

**Severity**: Warning/Error (configurable thresholds)

**Default Thresholds**:

- Warning: 50% sequential scan ratio
- Error: 90% sequential scan ratio

**Why This Matters**:

- High sequential scan ratios indicate poor query performance
- Suggests missing or ineffective indexes
- Can significantly impact application response times

**Example Output**:

```text
Found 2 tables with seq scan percentage > 50%: public.orders (seq scan %: 75.1), public.logs (seq scan %: 82.3)
```

**How to Fix**:

1. Analyze query patterns on affected tables
2. Create indexes on frequently filtered columns
3. Consider composite indexes for multi-column WHERE clauses
4. Review and optimize slow queries

**Threshold Configuration**:

```sql
-- Make T005 more sensitive
SELECT pglinter.update_rule_levels('T005', 30.0, 70.0);

-- Check current thresholds
SELECT pglinter.get_rule_levels('T005');
```

---

### T006: Cross-Schema Foreign Keys

**Description**: Detects foreign keys that reference tables in different schemas.

**Severity**: Warning

**Why This Matters**:

- Can complicate schema migrations and maintenance
- May indicate poor schema organization
- Can create unwanted dependencies between schemas

**Example Output**:

```text
Found tables with cross-schema foreign keys
```

**How to Fix**:

1. Reorganize tables to minimize cross-schema references
2. Consider if schemas should be merged
3. Document dependencies clearly if cross-schema references are necessary

---

### T007: Unused Indexes (Table-Specific)

**Description**: Identifies unused indexes on specific tables with size information.

**Severity**: Warning

**Default Threshold**: 1MB minimum size

**Why This Matters**:

- Table-specific version of B004 with size details
- Helps prioritize index removal based on storage impact

**Example Output**:

```text
Found 2 unused indexes larger than 1MB: public.orders.idx_old_status (5MB), public.users.idx_temp (3MB)
```

**How to Fix**:

- See B004 remediation guidance
- Prioritize larger unused indexes for removal

---

### T008: Foreign Key Type Mismatches

**Description**: Detects foreign keys where the referencing and referenced columns have different data types.

**Severity**: Error

**Why This Matters**:

- Type mismatches can prevent proper foreign key constraint creation
- May cause performance issues during joins
- Indicates data modeling problems

**Example Output**:

```text
Found 1 foreign key type mismatches: public.orders.customer_id (integer) -> customers.id (bigint) [FK: fk_customer]
```

**How to Fix**:

1. Align data types between referencing and referenced columns
2. Use consistent type conventions across related tables
3. Consider migration impact when changing existing types

**SQL Example**:

```sql
-- Fix type mismatch
ALTER TABLE orders ALTER COLUMN customer_id TYPE bigint;
```

---

### T009: Tables Without Role Grants

**Description**: Identifies tables that have no specific role grants.

**Severity**: Warning

**Why This Matters**:

- Tables without explicit grants may be inaccessible to application users
- Indicates incomplete security configuration
- Can cause application access issues

**Example Output**:

```text
Found 3 tables without role grants: public.logs, public.temp_data, public.archive
```

**How to Fix**:

1. Grant appropriate privileges to application roles
2. Set up default privileges for future objects
3. Review and document access control strategy

**SQL Example**:

```sql
-- Grant table access to application role
GRANT SELECT, INSERT, UPDATE, DELETE ON logs TO app_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_user;
```

---

### T010: Reserved Keywords Usage

**Description**: Detects tables and columns using PostgreSQL reserved keywords.

**Severity**: Warning

**Why This Matters**:

- Reserved keywords require quoting in SQL statements
- Can cause parser confusion and syntax errors
- Makes code harder to read and maintain
- May cause issues during database migrations

**Example Output**:

```text
Found tables/columns using reserved keywords
```

**How to Fix**:

1. Rename tables and columns to avoid reserved keywords
2. Use descriptive, non-reserved alternatives
3. Plan migration strategy for existing objects

**Common Reserved Keywords**:

- SELECT, FROM, WHERE, ORDER, GROUP
- TABLE, INDEX, CREATE, DROP, ALTER
- PRIMARY, FOREIGN, UNIQUE, NOT, NULL

**SQL Example**:

```sql
-- Rename table using reserved keyword
ALTER TABLE "order" RENAME TO customer_order;

-- Rename column using reserved keyword
ALTER TABLE products RENAME COLUMN "select" TO selection_flag;
```

---

### T011: Uppercase Names (Table-Specific)

**Description**: Table-specific detection of uppercase letters in table and column names.

**Severity**: Warning

**Why This Matters**:

- Same as B006 but provides table-level detail
- Helps prioritize which tables to rename first

**Example Output**:

```text
Found 2 database objects with uppercase letters: public.UserProfiles (table), public.orders.CustomerId (column)
```

**How to Fix**:

- See B006 remediation guidance
- Focus on the specific objects identified

---

### T012: Sensitive Columns

**Description**: Detects potentially sensitive columns using the PostgreSQL anonymizer extension.

**Severity**: Warning

**Prerequisites**: Requires `anon` extension to be installed

**Why This Matters**:

- Helps identify data that may need privacy protection
- Assists with GDPR and data protection compliance
- Highlights columns that should be masked in non-production environments

**Example Output**:

```text
Found 3 potentially sensitive columns: public.users.email (email), public.customers.phone (phone), public.profiles.ssn (identifier)
```

**How to Fix**:

1. Install and configure the anon extension
2. Create masking rules for sensitive columns
3. Implement data anonymization for non-production environments
4. Document sensitive data handling procedures

**SQL Example**:

```sql
-- Install anon extension
CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- Create masking rule
SELECT anon.mask_column('public.users.email', 'anon.fake_email()');
```

---

## Schema Rules (S-series)

Schema-level checks for organization and security.

### S001: Schemas Without Default Privileges

**Description**: Detects schemas that lack default role grants for future objects.

**Severity**: Warning

**Why This Matters**:

- Without default privileges, new tables won't automatically inherit permissions
- Requires manual grant management for each new object
- Can lead to access control gaps

**Example Output**:

```text
Found 2 schemas without default role grants: reporting, analytics
```

**How to Fix**:

1. Set up default privileges for each schema
2. Grant privileges to appropriate application roles
3. Document privilege management strategy

**SQL Example**:

```sql
-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA reporting
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

-- Set default privileges for future sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA reporting
GRANT USAGE ON SEQUENCES TO app_user;
```

---

### S002: Environment-Named Schemas

**Description**: Detects schemas with environment prefixes/suffixes (dev_, _staging, prod_, etc.).

**Severity**: Warning

**Why This Matters**:

- Environment-specific schemas in production can indicate configuration issues
- May suggest improper environment separation
- Can lead to deployment and management confusion

**Example Output**:

```text
Found 3 schemas with environment prefixes/suffixes: dev_analytics, prod_sales, testing_data
```

**How to Fix**:

1. Use environment-specific databases instead of schemas
2. Rename schemas to remove environment indicators
3. Implement proper environment separation strategy
4. Use configuration management for environment-specific settings

**Environment Patterns Detected**:

- Prefixes: `dev_`, `test_`, `prod_`, `staging_`
- Suffixes: `_dev`, `_test`, `_prod`, `_staging`

---

## Rule Management

### Viewing Rules

```sql
-- Show all available rules
SELECT * FROM pglinter.show_rules();

-- Show only enabled rules
SELECT * FROM pglinter.show_rules() WHERE enabled = true;

-- Show rules by category
SELECT * FROM pglinter.show_rules() WHERE rule_code LIKE 'B%';
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
```

### Rule Explanations

```sql
-- Get detailed explanation for any rule
SELECT pglinter.explain_rule('T005');

-- Get explanations for all rules
SELECT rule_code, pglinter.explain_rule(rule_code) as explanation
FROM pglinter.show_rules()
ORDER BY rule_code;
```

### Configurable Thresholds

Some rules support configurable warning and error thresholds:

```sql
-- Check current thresholds (currently only T005 supports this)
SELECT pglinter.get_rule_levels('T005');

-- Update thresholds
SELECT pglinter.update_rule_levels('T005', 30.0, 70.0);

-- Reset to defaults
SELECT pglinter.update_rule_levels('T005', 50.0, 90.0);
```

---

## Best Practices

### Rule Selection by Environment

**Development Environment**:

- Enable all rules to catch issues early
- Use relaxed thresholds for T005 (70%/95%)
- Focus on structural issues (B001, T001, T008)

**Staging Environment**:

- Enable all rules with moderate thresholds
- Use T005 thresholds around 40%/80%
- Focus on performance rules (T005, T007, B004)

**Production Environment**:

- Enable critical rules with sensitive thresholds
- Use T005 thresholds around 30%/70%
- Monitor continuously for performance degradation

### Rule Prioritization

**High Priority** (Fix immediately):

- T008: Foreign key type mismatches
- C001: Memory configuration issues
- C002: Insecure authentication methods

**Medium Priority** (Plan fixes):

- B001, T001: Missing primary keys
- T005: High sequential scan usage
- B003, T004: Missing foreign key indexes

**Low Priority** (Improve over time):

- B006, T011: Uppercase naming
- T010: Reserved keyword usage
- S002: Environment-named schemas

### Integration Strategies

**CI/CD Integration**:

```bash
# Run checks as part of deployment pipeline
psql -c "SELECT pglinter.perform_base_check('/tmp/results.sarif')"
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
SELECT pglinter.disable_rule('T005');
SELECT pglinter.disable_rule('B006');
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

1. Check if rule is enabled: `SELECT pglinter.is_rule_enabled('T005');`
2. Verify thresholds: `SELECT pglinter.get_rule_levels('T005');`
3. Check rule explanation: `SELECT pglinter.explain_rule('T005');`

**Performance impact**:

1. Rules analyze system catalogs and statistics
2. Run during maintenance windows for large databases
3. Consider disabling resource-intensive rules if needed

**False positives**:

1. Adjust thresholds for environment-specific needs
2. Disable rules that don't apply to your use case
3. Document exceptions and reasoning

### Getting Help

- Review rule explanations: `SELECT pglinter.explain_rule('RULE_CODE');`
- Check GitHub issues for known problems
- Contribute improvements and feedback

---

# This documentation covers all currently implemented rules. New rules and

features are added regularly - check the [Functions
Reference](../functions/README.md) for the latest capabilities
