-- =============================================================================
-- pglinter Rules Configuration
-- =============================================================================
--
-- This file defines the comprehensive rule set for the pglinter PostgreSQL
-- extension. It creates the rules table that stores metadata for all
-- database analysis rules.
--
-- Rule Categories:
--   B-series: Base Database Rules (tables, indexes, primary keys, etc.)
--   C-series: Cluster Rules (configuration, security, performance)
--   S-series: Schema Rules (permissions, ownership, security)
--
-- Each rule includes:
--   - Rule code (e.g., B001, T003)
--   - Scope (BASE, CLUSTER, SCHEMA, TABLE)
--   - Descriptive metadata and fix suggestions
--
-- Usage:
--   This file is automatically executed during extension installation
--   via pgrx's extension_sql_file! macro.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS pglinter.rules (
    id SERIAL PRIMARY KEY,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE,
    scope TEXT,
    description TEXT,
    message TEXT,
    fixes TEXT []
);


-- Clear existing data and insert comprehensive rules
DELETE FROM pglinter.rules;

INSERT INTO pglinter.rules (
    name,
    code,
    scope,
    description,
    message,
    fixes
) VALUES
-- Base Database Rules (B series)
(
    'HowManyTableWithoutPrimaryKey', 'B001', 'BASE',
    'Count number of tables without primary key.',
    '{0}/{1} table(s) without primary key. Object list:\n{4}',
    ARRAY['create a primary key']
),
(
    'HowManyRedudantIndex', 'B002', 'BASE',
    'Count number of redundant index vs nb index.',
    '{0}/{1} redundant(s) index. Object list:\n{4}',
    ARRAY[
        'remove duplicated index or check if a constraint does not create a redundant index'
    ]
),
(
    'HowManyTableWithoutIndexOnFk', 'B003', 'BASE',
    'Count number of tables without index on foreign key.',
    '{0}/{1} table(s) without index on foreign key. Object list:\n{4}',
    ARRAY['create an index on foreign key columns']
),
(
    'HowManyUnusedIndex', 'B004', 'BASE',
    'Count number of unused index vs nb index (base on pg_stat_user_indexes, indexes associated to unique constraints are discard.)',
    '{0}/{1} unused index. Object list:\n{4}',
    ARRAY['remove unused index']
),
(
    'HowManyObjectsWithUppercase', 'B005', 'BASE',
    'Count number of objects with uppercase in name or in columns.',
    '{0}/{1} object(s) using uppercase for name or columns. Object list:\n{4}',
    ARRAY['Do not use uppercase for any database objects']
),
(
    'HowManyTablesNeverSelected', 'B006', 'BASE',
    'Count number of table(s) that has never been selected.',
    '{0}/{1} table(s) are never selected. Object list:\n{4}',
    ARRAY[
        'Is it necessary to update/delete/insert rows in table(s) that are never selected ?'
    ]
),
(
    'HowManyTablesWithFkOutsideSchema', 'B007', 'BASE',
    'Count number of tables with foreign keys outside their schema.',
    '{0}/{1} table(s) with foreign keys outside schema. Object list:\n{4}',
    ARRAY[
        'Consider restructuring schema design to keep related tables in same schema',
        'ask a dba'
    ]
),
(
    'HowManyTablesWithFkMismatch', 'B008', 'BASE',
    'Count number of tables with foreign keys that do not match the key reference type.',
    '{0}/{1} table(s) with foreign key mismatch. Object list:\n{4}',
    ARRAY[
        'Consider column type adjustments to ensure foreign key matches referenced key type',
        'ask a dba'
    ]
),
(
    'HowManyTablesWithSameTrigger', 'B009', 'BASE',
    'Count number of tables using the same trigger vs nb table with their own triggers.',
    '{0}/{1} table(s) using the same trigger function. Object list:\n{4}',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ]
),
(
    'HowManyTablesWithReservedKeywords', 'B010', 'BASE',
    'Count number of database objects using reserved keywords in their names.',
    '{0}/{1} object(s) using reserved keywords. Object list:\n{4}',
    ARRAY[
        'Rename database objects to avoid using reserved keywords.',
        'Using reserved keywords can lead to SQL syntax errors and maintenance difficulties.'
    ]
),
(
    'SeveralTableOwnerInSchema', 'B011', 'BASE',
    'In a schema there are several tables owned by different owners.',
    '{0}/{1} schemas have tables owned by different owners. Object list:\n{4}',
    ARRAY['change table owners to the same functional role']
),
(
    'CompositePrimaryKeyTooManyColumns', 'B012', 'BASE',
    'Detect tables with composite primary keys involving more than 4 columns',
    '{0} table(s) have composite primary keys with more than 4 columns. Object list:\n{4}',
    ARRAY[
        'Consider redesigning the table to avoid composite primary keys with more than 4 columns',
        'Use surrogate keys (e.g., serial, UUID) instead of composite primary keys, and establish unique constraints on necessary column combinations, to enforce uniqueness.'
    ]
),
(
    'HowManyTablesWithRowByRowTriggerWithoutWhereClause',
    'B013',
    'BASE',
    'Count number of tables using a row by row processing without any where clause vs nb table with their own triggers.',
    '{0}/{1} table(s) using row by row processing without any where clause. Object list:\n{4}',
    ARRAY[
        'Prefer using set-based operations instead of row by row processing for better performance.',
        'If not possible, consider adding a WHERE clause to limit the rows processed.'
    ]
),
(
    'SchemaWithDefaultRoleNotGranted', 'S001', 'SCHEMA',
    'The schema has no default role. Means that futur table will not be granted through a role. So you will have to re-execute grants on it.',
    'No default role grantee on schema {0}.{1}. It means that each time a table is created, you must grant it to roles. Object list:\n{4}',
    ARRAY[
        'add a default privilege=> ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> for user <schema''s owner>'
    ]
),

(
    'SchemaPrefixedOrSuffixedWithEnvt', 'S002', 'SCHEMA',
    'The schema is prefixed with one of staging,stg,preprod,prod,sandbox,sbox string. Means that when you refresh your preprod, staging environments from production, you have to rename the target schema from prod_ to stg_ or something like. It is possible, but it is never easy.',
    '{0}/{1} schemas are prefixed or suffixed with environment names. Prefer prefix or suffix the database name instead. Object list:\n{4}',
    ARRAY[
        'Keep the same schema name across environments. Prefer prefix or suffix the database name'
    ]
),
(
    'UnsecuredPublicSchema', 'S003', 'SCHEMA',
    'Only authorized users should be allowed to create objects.',
    '{0}/{1} schemas are unsecured, schemas where all users can create objects in. Object list:\n{4}',
    ARRAY['REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC']
),
(
    'OwnerSchemaIsInternalRole', 'S004', 'SCHEMA',
    'Owner of schema should not be any internal pg roles, or owner is a superuser (not sure it is necesary).',
    '{0}/{1} schemas are owned by internal roles or superuser. Object list:\n{4}',
    ARRAY['change schema owner to a functional role']
),
(
    'SchemaOwnerDoNotMatchTableOwner', 'S005', 'SCHEMA',
    'The schema owner and tables in the schema do not match.',
    '{0}/{1} in the same schema, tables have different owners. They should be the same. Object list:\n{4}',
    ARRAY[
        'For maintenance facilities, schema and tables owners should be the same.'
    ]
),
(
    'PgHbaEntriesWithMethodTrustShouldNotExists',
    'C001',
    'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust authentication method.',
    ARRAY['change trust method in pg_hba.conf']
),
(
    'PgHbaEntriesWithMethodTrustOrPasswordShouldNotExists',
    'C002',
    'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust or password authentication method.',
    ARRAY['change trust or password method in pg_hba.conf']
),
(
    'PasswordEncryptionIsMd5',
    'C003',
    'CLUSTER',
    'This configuration is not secure anymore and will prevent an upgrade to Postgres 18. Warning, you will need to reset all passwords after this is changed to scram-sha-256.',
    'Encrypted passwords with MD5.',
    ARRAY[
        'change password_encryption parameter to scram-sha-256 (ALTER SYSTEM SET password_encryption = ''scram-sha-256'' ). Warning, you will need to reset all passwords after this parameter is updated.'
    ]
);


-- =============================================================================
-- Rule Messages Table Creation
-- =============================================================================
CREATE TABLE IF NOT EXISTS pglinter.rule_messages (
    id SERIAL PRIMARY KEY,
    code TEXT,
    rule_msg JSONB
);

DELETE FROM pglinter.rule_messages;

INSERT INTO pglinter.rule_messages (code, rule_msg) VALUES
(
    'S001',
    '{"severity": "WARNING", "message": "Schema {object} has no default role.", "advices": "Add a default privilege to the schema so future tables are granted to a role automatically.", "infos": ["How to fix: ALTER DEFAULT PRIVILEGES IN SCHEMA {object} FOR USER <owner> GRANT ...;"]}'
),
(
    'S002',
    '{"severity": "WARNING", "message": "Schema {object} is prefixed or suffixed with an environment name.", "advices": "Keep the same schema name across environments. Prefer prefixing or suffixing the database name instead.", "infos": ["How to fix: Rename schema {object} to a neutral name."]}'
),
(
    'S003',
    '{"severity": "WARNING", "message": "Schema {object} is unsecured: PUBLIC can create objects.", "advices": "REVOKE CREATE ON SCHEMA from PUBLIC to restrict object creation.", "infos": ["How to fix: REVOKE CREATE ON SCHEMA {object} FROM PUBLIC;"]}'
),
(
    'S004',
    '{"severity": "WARNING", "message": "Schema {object} is owned by an internal role or superuser.", "advices": "Change schema owner to a functional role for better security and maintainability.", "infos": ["How to fix: ALTER SCHEMA {object} OWNER TO <role>;"]}'
),
(
    'S005',
    '{"severity": "WARNING", "message": "Schema {object} and its tables have different owners.", "advices": "For easier maintenance, schema and tables should have the same owner.", "infos": ["How to fix: ALTER TABLE {object} OWNER TO <role>;"]}'
);

INSERT INTO pglinter.rule_messages (code, rule_msg) VALUES
(
    'B001',
    '{"severity": "WARNING", "message": "{object} does not have a primary key.", "advices": "Add a primary key to this table to ensure data integrity and better performance.", "infos": ["How to fix: ALTER TABLE {object} ADD PRIMARY KEY (...);"]}'
),
(
    'B002',
    '{"severity": "WARNING", "message": "{object} is a redundant index.", "advices": "Remove redundant or duplicate indexes to optimize performance and storage.", "infos": ["How to fix: DROP INDEX {object}; or review constraints that may create duplicate indexes."]}'
),
(
    'B003',
    '{"severity": "WARNING", "message": "{object} does not have an index on its foreign key.", "advices": "Create an index on the foreign key column to improve join and lookup performance.", "infos": ["How to fix: CREATE INDEX ON {object} (...);"]}'
),
(
    'B004',
    '{"severity": "WARNING", "message": "{object} is an unused index.", "advices": "Remove unused indexes to reduce storage and maintenance overhead.", "infos": ["How to fix: DROP INDEX {object}; or review index usage statistics."]}'
),
(
    'B005',
    '{"severity": "WARNING", "message": "{object} uses uppercase characters.", "advices": "Using uppercase in identifiers requires quoting and can cause case-sensitivity issues.", "infos": ["How to fix: Rename the database object to use only lowercase characters."]}'
),
(
    'B006',
    '{"severity": "WARNING", "message": "{object} has never been selected.", "advices": "Review the necessity of this table. If it is not needed, consider removing it or archiving its data.", "infos": ["How to fix: DROP TABLE {object}; or investigate application usage."]}'
),
(
    'B007',
    '{"severity": "WARNING", "message": "{object} has foreign keys outside its schema.", "advices": "Consider restructuring schema design to keep related tables in the same schema.", "infos": ["How to fix: Move related tables into the same schema or review schema design."]}'
),
(
    'B008',
    '{"severity": "WARNING", "message": "{object} has a foreign key type mismatch.", "advices": "Adjust column types to ensure foreign key matches referenced key type.", "infos": ["How to fix: ALTER TABLE {object} ALTER COLUMN ... TYPE ...;"]}'
),
(
    'B009',
    '{"severity": "WARNING", "message": "{object} shares a trigger function with other tables.", "advices": "Use one trigger function per table for clarity and maintainability.", "infos": ["How to fix: CREATE a dedicated trigger function for {object} and update the trigger."]}'
),
(
    'B010',
    '{"severity": "WARNING", "message": "{object} uses a reserved SQL keyword as its name.", "advices": "Rename database objects to avoid using reserved keywords.", "infos": ["How to fix: ALTER TABLE/INDEX/VIEW/FUNCTION/TYPE {object} RENAME TO ...;"]}'
),
(
    'B011',
    '{"severity": "WARNING", "message": "{object} schema has tables with different owners.", "advices": "Change table owners to the same functional role for easier maintenance.", "infos": ["How to fix: ALTER TABLE {object} OWNER TO ...;"]}'
),
(
    'B012',
    '{"severity": "WARNING", "message": "{object} has a composite primary key with more than 4 columns.", "advices": "Consider redesigning the table to avoid composite primary keys with more than 4 columns. Use surrogate keys if possible.", "infos": ["How to fix: Redesign {object} to use a surrogate key and unique constraints."]}'
),
(
    'B013',
    '{"severity": "WARNING", "message": "{object} uses a trigger function, that uses a cursor and a row by row processing, without any WHERE clause. Fired trigger can cause performance issues.", "advices": "If possible avoid row by row processing. Use base processing instead. If not possible, then add a where clause to limit the number of returned rows.", "infos": ["How to fix: remove the cursor or add a where clause to the cursor. {object}."]}'
);
