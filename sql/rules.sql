CREATE TABLE IF NOT EXISTS pglinter.rules (
    id INT PRIMARY KEY,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE,
    warning_level INT,
    error_level INT,
    scope TEXT,
    description TEXT,
    message TEXT,
    fixes TEXT[]
);

-- Clear existing data and insert comprehensive rules
DELETE FROM pglinter.rules;

INSERT INTO pglinter.rules (id,name,code,warning_level,error_level,scope,description,message,fixes) VALUES
-- Base Database Rules (B series)
(1, 'HowManyTableWithoutPrimaryKey', 'B001', 20, 80, 'BASE',
    'Count number of tables without primary key.',
    '{0}/{1} table(s) without primary key exceed the {2} threshold: {3}%.',
    ARRAY['create a primary key or change warning/error threshold']),

(2, 'HowManyRedudantIndex', 'B002', 20, 80, 'BASE',
    'Count number of redundant index vs nb index.',
    '{0}/{1} redundant(s) index exceed the {2} threshold: {3}%.',
    ARRAY['remove duplicated index or check if a constraint does not create a redundant index, or change warning/error threshold']),

(3, 'HowManyTableWithoutIndexOnFk', 'B003', 20, 80, 'BASE',
    'Count number of tables without index on foreign key.',
    '{0}/{1} table(s) without index on foreign key exceed the {2} threshold: {3}%.',
    ARRAY['create a index on foreign key or change warning/error threshold']),

(4, 'HowManyUnusedIndex', 'B004', 20, 80, 'BASE',
    'Count number of unused index vs nb index (base on pg_stat_user_indexes, indexes associated to unique constraints are discard.)',
    '{0}/{1} unused index exceed the {2} threshold: {3}%',
    ARRAY['remove unused index or change warning/error threshold']),

(5, 'UnsecuredPublicSchema', 'B005', 20, 80, 'BASE',
    'Only authorized users should be allowed to create objects.',
    '{0}/{1} schemas are unsecured, schemas where all users can create objects in, exceed the {2} threshold: {3}%.',
    ARRAY['REVOKE CREATE ON SCHEMA <schema_name> FROM PUBLIC']),

(6, 'HowManyObjectsWithUppercase', 'B006', 20, 80, 'BASE',
    'Count number of objects with uppercase in name or in columns.',
    '{0}/{1} object(s) using uppercase for name or columns exceed the {2} threshold: {3}%.',
    ARRAY['Do not use uppercase for any database objects']),

-- Cluster Rules (C series)
(10, 'MaxConnectionsByWorkMemIsNotLargerThanMemory', 'C001', 1, 1, 'CLUSTER',
    'Number of cx (max_connections * work_mem) is not greater than memory.',
    'work_mem * max_connections is bigger than ram.',
    ARRAY['downsize max_connections or upsize memory']),

(11, 'PgHbaEntriesWithMethodTrustOrPasswordShouldNotExists', 'C002', 20, 80, 'CLUSTER',
    'This configuration is extremely insecure and should only be used in a controlled, non-production environment for testing purposes. In a production environment, you should use more secure authentication methods such as md5, scram-sha-256, or cert, and restrict access to trusted IP addresses only.',
    '{0} entries in pg_hba.conf with trust or password authentication method exceed the warning threshold: {1}.',
    ARRAY['change trust or password method in pg_hba.conf']),

-- Table Rules (T series)
(20, 'TableWithoutPrimaryKey', 'T001', 1, 1, 'TABLE',
    'table without primary key.',
    'No primary key on table {0}.{1}.{2}.',
    ARRAY['create a primary key']),

(21, 'TableWithoutIndex', 'T002', 1, 1, 'TABLE',
    'table without index.',
    'No index on table {0}.{1}.{2}.',
    ARRAY['check if it''s necessary to create index']),

(22, 'TableWithRedundantIndex', 'T003', 10, 20, 'TABLE',
    'table without duplicated index.',
    '{0} redundant(s) index found on {1}.{2} idx {3} column {4}.',
    ARRAY['remove duplicated index','check for constraints that create indexes.']),

(23, 'TableWithFkNotIndexed', 'T004', 1, 1, 'TABLE',
    'table without index on fk.',
    'unindexed fk {0}.{1}.{2}.',
    ARRAY['{3}']),

(24, 'TableWithPotentialMissingIdx', 'T005', 50, 90, 'TABLE',
    ' with high level of seq scan, base on pg_stat_user_tables.',
    '{0} table with seq scan exceed the threshold: {1}.',
    ARRAY['ask a dba']),

(25, 'TableWithFkOutsideSchema', 'T006', 1, 1, 'TABLE',
    'table with fk outside its schema.',
    'fk {0} on {1} is in schema {2}.',
    ARRAY['consider rewrite your model', 'ask a dba']),

(26, 'TableWithUnusedIndex', 'T007', 1, 1, 'TABLE',
    'Table unused index, base on pg_stat_user_indexes, indexes associated to unique constraints are discard.',
    'Index {0} on {1} size {2} Mo seems to be unused (idx_scan=0).',
    ARRAY['remove unused index or change warning/error threshold']),

(27, 'TableWithFkMismatch', 'T008', 1, 1, 'TABLE',
    'table with fk mismatch, ex smallint refer to a bigint.',
    'Type constraint mismatch: {0} on {1} column {2} (type {3}/{4}) ref {5} column {6} type ({7}/{8}).',
    ARRAY['consider rewrite your model', 'ask a dba']),

(28, 'TableWithRoleNotGranted', 'T009', 1, 1, 'TABLE',
    'Table has no roles grantee. Meaning that users will need direct access on it (not through a role).',
    'No role grantee on table {0}.{1}.{2}. It means that except owner. Others will need a direct grant on this table, not through a role (unusual at dkt).',
    ARRAY['create roles (myschema_ro & myschema_rw) and grant it on table with appropriate privileges']),

(29, 'ReservedKeyWord', 'T010', 10, 20, 'TABLE',
    'A table, his column or indexes use reserved keywords.',
    '{0} {1}.{2}.{3}.{4} violate retricted keyword rule.',
    ARRAY['Rename the object to use a non reserved keyword']),

(30, 'TableWithUppercase', 'T011', 1, 1, 'TABLE',
    'Table with uppercase in name or in columns.',
    'Uppercase used on table {0}.{1}.{2}.',
    ARRAY['Do not use uppercase for any database objects']),

(31, 'TableWithSensibleColumn', 'T012', 50, 80, 'TABLE',
    'Base on the extension anon (https://postgresql-anonymizer.readthedocs.io/en/stable/detection), show sensitive column.',
    '{0} have column {1} (category {2}) that can be consider has sensitive. It should be masked for non data-operator users.',
    ARRAY['Install extension anon, and create some masking rules on']),

-- Schema Rules (S series)
(40, 'SchemaWithDefaultRoleNotGranted', 'S001', 1, 1, 'SCHEMA',
    'The schema ha no default role. Means that futur table will not be granted through a role. So you will have to re-execute grants on it.',
    'No default role grantee on schema {0}.{1}. It means that each time a table is created, you must grant it to roles.',
    ARRAY['add a default privilege=> ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> for user <schema''s owner>']),

(41, 'SchemaPrefixedOrSuffixedWithEnvt', 'S002', 1, 1, 'SCHEMA',
    'The schema is prefixed with one of staging,stg,preprod,prod,sandbox,sbox string. Means that when you refresh your preprod, staging environments from production, you have to rename the target schema from prod_ to stg_ or something like. It is possible, but it is never easy.',
    'You should not prefix or suffix the schema name with {0}. You may have difficulties when refreshing environments. Prefer prefix or suffix the database name.',
    ARRAY['Keep the same schema name across environments. Prefer prefix or suffix the database name']);


GRANT USAGE ON SCHEMA PGLINTER TO PUBLIC;
