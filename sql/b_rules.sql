
INSERT INTO rules (
    name,
    code,
    warning_level,
    error_level,
    scope,
    description,
    message,
    fixes
) VALUES
-- Base Database Rules (B series)
(
    'HowManyTableWithoutPrimaryKey', 'B001', 20, 80, 'BASE',
    'Count number of tables without primary key.',
    '{0}/{1} table(s) without primary key exceed the {2} threshold: {3}%. Object list:\n{4}',
    ARRAY['create a primary key or change warning/error threshold']
),
(
    'HowManyRedudantIndex', 'B002', 20, 80, 'BASE',
    'Count number of redundant index vs nb index.',
    '{0}/{1} redundant(s) index exceed the {2} threshold: {3}%.',
    ARRAY[
        'remove duplicated index or check if a constraint does not create a redundant index, or change warning/error threshold'
    ]
),
(
    'HowManyTableWithoutIndexOnFk', 'B003', 20, 80, 'BASE',
    'Count number of tables without index on foreign key.',
    '{0}/{1} table(s) without index on foreign key exceed the {2} threshold: {3}%.',
    ARRAY['create a index on foreign key or change warning/error threshold']
),
(
    'HowManyUnusedIndex', 'B004', 20, 80, 'BASE',
    'Count number of unused index vs nb index (base on pg_stat_user_indexes, indexes associated to unique constraints are discard.)',
    '{0}/{1} unused index exceed the {2} threshold: {3}%',
    ARRAY['remove unused index or change warning/error threshold']
),
(
    'HowManyObjectsWithUppercase', 'B005', 20, 80, 'BASE',
    'Count number of objects with uppercase in name or in columns.',
    '{0}/{1} object(s) using uppercase for name or columns exceed the {2} threshold: {3}%.',
    ARRAY['Do not use uppercase for any database objects']
),
(
    'HowManyTablesNeverSelected', 'B006', 20, 80, 'BASE',
    'Count number of table(s) that has never been selected.',
    '{0}/{1} table(s) are never selected the {2} threshold: {3}%.',
    ARRAY[
        'Is it necessary to update/delete/insert rows in table(s) that are never selected ?'
    ]
),
(
    'HowManyTablesWithFkOutsideSchema', 'B007', 20, 80, 'BASE',
    'Count number of tables with foreign keys outside their schema.',
    '{0}/{1} table(s) with foreign keys outside schema exceed the {2} threshold: {3}%.',
    ARRAY[
        'Consider restructuring schema design to keep related tables in same schema',
        'ask a dba'
    ]
),
(
    'HowManyTableSharingSameTrigger', 'B015', 20, 80, 'BASE',
    'Count number of table that use the same trigger vs nb table with their own triggers.',
    '{0}/{1} table(s) using the same trigger function exceed the {2} threshold: {3}%.',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ]
);


-- -- =============================================================================
-- -- B002 - Redundant Indexes (Total Index Count Query)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT COUNT(*) AS total_indexes
-- FROM pg_indexes
-- WHERE
--     schemaname NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B002';

-- -- =============================================================================
-- -- B002 - Redundant Indexes (Problem Query)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q2 = $$
-- SELECT COUNT(*) AS redundant_indexes
-- FROM (
--     SELECT DISTINCT i1.indexrelid
--     FROM pg_index i1, pg_index i2
--     WHERE
--         i1.indrelid = i2.indrelid
--         AND i1.indexrelid != i2.indexrelid
--         AND i1.indkey = i2.indkey
--         AND EXISTS (
--             SELECT 1 FROM pg_indexes pi1
--             WHERE
--                 pi1.indexname
--                 = (
--                     SELECT relname FROM pg_class
--                     WHERE oid = i1.indexrelid
--                 )
--                 AND pi1.schemaname NOT IN (
--                     'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--                 )
--         )
-- ) redundant
-- $$
-- WHERE code = 'B002';

-- -- -- =============================================================================
-- -- -- C001 - Memory Configuration Analysis
-- -- -- =============================================================================
-- -- UPDATE pglinter.rules
-- -- SET q1 = $$
-- -- SELECT
-- --     current_setting('max_connections')::int AS max_connections,
-- --     current_setting('work_mem') AS work_mem_setting
-- -- $$
-- -- WHERE code = 'C001';



-- -- =============================================================================
-- -- B003 - Foreign Key Index Coverage (Total)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT count(DISTINCT tc.table_name)::INT AS total_tables
-- FROM
--     information_schema.table_constraints AS tc
-- WHERE
--     tc.constraint_type = 'FOREIGN KEY'
--     AND tc.table_schema NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B003';



-- -- =============================================================================
-- -- B003 - Foreign Key Index Coverage (Problems)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q2 = $$
-- SELECT COUNT(DISTINCT c.relname)::INT AS tables_with_unindexed_foreign_keys
-- FROM pg_constraint con
-- JOIN pg_class c ON c.oid = con.conrelid
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- LEFT JOIN
--     pg_index i
--     ON i.indrelid = c.oid AND con.conkey::smallint [] <@ i.indkey::smallint []
-- WHERE
--     con.contype = 'f'
--     AND c.relkind = 'r'
--     AND i.indexrelid IS NULL
--     AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema', 'pglinter')
-- $$
-- WHERE code = 'B003';


-- -- =============================================================================
-- -- B004 - Manual Index Usage (Total)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT COUNT(*) AS total_manual_indexes
-- FROM pg_stat_user_indexes AS psu
-- JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
-- WHERE
--     pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
--     -- Excludes indexes created for a UNIQUE constraint
--     AND pgi.indisunique = FALSE
--     AND psu.schemaname NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B004';

-- -- =============================================================================
-- -- B004 - Manual Index Usage (Problems - Unused)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q2 = $$
-- SELECT COUNT(*) AS unused_manual_indexes
-- FROM pg_stat_user_indexes AS psu
-- JOIN pg_index AS pgi ON psu.indexrelid = pgi.indexrelid
-- WHERE
--     psu.idx_scan = 0
--     AND pgi.indisprimary = FALSE -- Excludes indexes created for a PRIMARY KEY
--     -- Excludes indexes created for a UNIQUE constraint
--     AND pgi.indisunique = FALSE
--     AND psu.schemaname NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B004';


-- -- =============================================================================
-- -- B005 - Objects With Uppercase (Total)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT COUNT(*) AS total_objects
-- FROM (
--     -- All tables
--     SELECT
--         'table' AS object_type,
--         table_schema AS schema_name,
--         table_name AS object_name
--     FROM information_schema.tables
--     WHERE
--         table_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )

--     UNION

--     -- All columns
--     SELECT
--         'column' AS object_type,
--         table_schema AS schema_name,
--         table_name || '.' || column_name AS object_name
--     FROM information_schema.columns
--     WHERE
--         table_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )

--     UNION

--     -- All indexes
--     SELECT
--         'index' AS object_type,
--         schemaname AS schema_name,
--         indexname AS object_name
--     FROM pg_indexes
--     WHERE
--         schemaname NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )

--     UNION

--     -- All sequences
--     SELECT
--         'sequence' AS object_type,
--         sequence_schema AS schema_name,
--         sequence_name AS object_name
--     FROM information_schema.sequences
--     WHERE
--         sequence_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )

--     UNION

--     -- All views
--     SELECT
--         'view' AS object_type,
--         table_schema AS schema_name,
--         table_name AS object_name
--     FROM information_schema.views
--     WHERE
--         table_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )

--     UNION

--     -- All functions
--     SELECT
--         'function' AS object_type,
--         routine_schema AS schema_name,
--         routine_name AS object_name
--     FROM information_schema.routines
--     WHERE
--         routine_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND routine_type = 'FUNCTION'

--     UNION

--     -- All triggers
--     SELECT
--         'trigger' AS object_type,
--         trigger_schema AS schema_name,
--         trigger_name AS object_name
--     FROM information_schema.triggers
--     WHERE
--         trigger_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )

--     UNION

--     -- All schemas
--     SELECT
--         'schema' AS object_type,
--         schema_name AS schema_name,
--         schema_name AS object_name
--     FROM information_schema.schemata
--     WHERE
--         schema_name NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
-- ) all_objects
-- $$
-- WHERE code = 'B005';

-- -- =============================================================================
-- -- B005 - Objects With Uppercase (Problems)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q2 = $$
-- SELECT COUNT(*) AS uppercase_objects
-- FROM (
--     -- Tables with uppercase names
--     SELECT
--         'table' AS object_type,
--         table_schema AS schema_name,
--         table_name AS object_name
--     FROM information_schema.tables
--     WHERE
--         table_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND table_name != LOWER(table_name)

--     UNION

--     -- Columns with uppercase names
--     SELECT
--         'column' AS object_type,
--         table_schema AS schema_name,
--         table_name || '.' || column_name AS object_name
--     FROM information_schema.columns
--     WHERE
--         table_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND column_name != LOWER(column_name)

--     UNION

--     -- Indexes with uppercase names
--     SELECT
--         'index' AS object_type,
--         schemaname AS schema_name,
--         indexname AS object_name
--     FROM pg_indexes
--     WHERE
--         schemaname NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND indexname != LOWER(indexname)

--     UNION

--     -- Sequences with uppercase names
--     SELECT
--         'sequence' AS object_type,
--         sequence_schema AS schema_name,
--         sequence_name AS object_name
--     FROM information_schema.sequences
--     WHERE
--         sequence_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND sequence_name != LOWER(sequence_name)

--     UNION

--     -- Views with uppercase names
--     SELECT
--         'view' AS object_type,
--         table_schema AS schema_name,
--         table_name AS object_name
--     FROM information_schema.views
--     WHERE
--         table_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND table_name != LOWER(table_name)

--     UNION

--     -- Functions with uppercase names
--     SELECT
--         'function' AS object_type,
--         routine_schema AS schema_name,
--         routine_name AS object_name
--     FROM information_schema.routines
--     WHERE
--         routine_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND routine_type = 'FUNCTION'
--         AND routine_name != LOWER(routine_name)

--     UNION

--     -- Triggers with uppercase names
--     SELECT
--         'trigger' AS object_type,
--         trigger_schema AS schema_name,
--         trigger_name AS object_name
--     FROM information_schema.triggers
--     WHERE
--         trigger_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND trigger_name != LOWER(trigger_name)

--     UNION

--     -- Schemas with uppercase names
--     SELECT
--         'schema' AS object_type,
--         schema_name AS schema_name,
--         schema_name AS object_name
--     FROM information_schema.schemata
--     WHERE
--         schema_name NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--         AND schema_name != LOWER(schema_name)
-- ) uppercase_objects
-- $$
-- WHERE code = 'B005';

-- -- =============================================================================
-- -- B006 - Tables Never Selected (Total)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT count(*)
-- FROM pg_catalog.pg_tables pt
-- WHERE
--     schemaname NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B006';

-- -- =============================================================================
-- -- B006 - Tables Never Selected (Problems)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q2 = $$
-- SELECT COUNT(*) AS unselected_tables
-- FROM pg_stat_user_tables AS psu
-- WHERE
--     (psu.idx_scan = 0 OR psu.idx_scan IS NULL)
--     AND (psu.seq_scan = 0 OR psu.seq_scan IS NULL)
--     AND n_tup_ins > 0
--     AND (n_tup_upd = 0 OR n_tup_upd IS NULL)
--     AND (n_tup_del = 0 OR n_tup_del IS NULL)
--     AND psu.schemaname NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B006';

-- -- =============================================================================
-- -- B007 - Tables With FK Outside Schema (Total)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT count(*)
-- FROM pg_catalog.pg_tables pt
-- WHERE
--     schemaname NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B007';

-- -- =============================================================================
-- -- B007 - Tables With FK Outside Schema (Problems)
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q2 = $$
-- SELECT
--     COUNT(
--         DISTINCT tc.table_schema || '.' || tc.table_name
--     ) AS tables_with_fk_outside_schema
-- FROM information_schema.table_constraints AS tc
-- INNER JOIN information_schema.constraint_column_usage AS ccu
--     ON tc.constraint_name = ccu.constraint_name
-- WHERE
--     tc.constraint_type = 'FOREIGN KEY'
--     AND tc.table_schema != ccu.table_schema
--     AND tc.table_schema NOT IN (
--         'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--     )
-- $$
-- WHERE code = 'B007';


-- -- =============================================================================
-- -- B015 - Tables With same trigger
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q1 = $$
-- SELECT
--     COALESCE(COUNT(DISTINCT event_object_table), 0)::BIGINT as table_using_trigger
-- FROM
--     information_schema.triggers t
-- WHERE
--     t.trigger_schema NOT IN (
--     'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
-- )
-- $$
-- WHERE code = 'B015';

-- -- =============================================================================
-- -- B015 - Tables With same trigger
-- -- =============================================================================
-- UPDATE pglinter.rules
-- SET q2 = $$
-- SELECT
--     COALESCE(SUM(shared_table_count), 0)::BIGINT AS table_using_same_trigger
-- FROM (
--     SELECT
--         COUNT(DISTINCT t.event_object_table) AS shared_table_count
--     FROM (
--         SELECT
--             t.event_object_table,
--             -- Extracts the function name from the action_statement (e.g., 'public.my_func()')
--             SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
--         FROM
--             information_schema.triggers t
--         WHERE
--             t.trigger_schema NOT IN (
--             'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
--         )
--     ) t
--     GROUP BY
--         t.trigger_function_name
--     HAVING
--         COUNT(DISTINCT t.event_object_table) > 1
-- ) shared_triggers
-- $$
-- WHERE code = 'B015';


