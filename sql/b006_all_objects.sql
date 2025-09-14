SELECT COUNT(*) as total_objects
FROM (
    -- All tables
    SELECT 'table' as object_type, table_schema as schema_name, table_name as object_name
    FROM information_schema.tables
    WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All columns
    SELECT 'column' as object_type, table_schema as schema_name,
           table_name || '.' || column_name as object_name
    FROM information_schema.columns
    WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All views
    SELECT 'view' as object_type, table_schema as schema_name, table_name as object_name
    FROM information_schema.views
    WHERE table_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All indexes
    SELECT 'index' as object_type, schemaname as schema_name, indexname as object_name
    FROM pg_indexes
    WHERE schemaname NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All sequences
    SELECT 'sequence' as object_type, sequence_schema as schema_name, sequence_name as object_name
    FROM information_schema.sequences
    WHERE sequence_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All functions/procedures
    SELECT 'function' as object_type, routine_schema as schema_name,
           routine_name || '(' || COALESCE(external_language, 'sql') || ')' as object_name
    FROM information_schema.routines
    WHERE routine_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All triggers
    SELECT 'trigger' as object_type, trigger_schema as schema_name,
           trigger_name || ' ON ' || event_object_table as object_name
    FROM information_schema.triggers
    WHERE trigger_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All user-defined constraints (matching the same exclusion rules as uppercase query)
    SELECT 'constraint' as object_type, constraint_schema as schema_name,
           constraint_name || ' ON ' || table_name as object_name
    FROM information_schema.table_constraints
    WHERE constraint_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')
    AND constraint_name NOT LIKE '%_pkey'  -- Exclude auto-generated primary key names
    AND constraint_name NOT LIKE '%_fkey'  -- Exclude auto-generated foreign key names
    AND constraint_name NOT LIKE '%_key'   -- Exclude auto-generated unique key names
    AND constraint_name NOT LIKE '%_check' -- Exclude auto-generated check constraint names

    UNION

    -- All user-defined schemas (excluding system schemas)
    SELECT 'schema' as object_type, '' as schema_name, schema_name as object_name
    FROM information_schema.schemata
    WHERE schema_name NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter', 'public')

    UNION

    -- All user-defined types
    SELECT 'type' as object_type, user_defined_type_schema as schema_name,
           user_defined_type_name as object_name
    FROM information_schema.user_defined_types
    WHERE user_defined_type_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

    UNION

    -- All domains
    SELECT 'domain' as object_type, domain_schema as schema_name, domain_name as object_name
    FROM information_schema.domains
    WHERE domain_schema NOT IN ('pg_toast', 'pg_catalog', 'information_schema', 'pglinter')

) all_objects
