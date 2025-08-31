# How-To Guides

Practical guides for common pglinter scenarios and use cases.

## Analyzing Large Databases

### Chunked Analysis

For very large databases, analyze in chunks:

```sql
-- analyze_by_schema.sql
DO $$
DECLARE
    schema_name text;
    result_file text;
BEGIN
    FOR schema_name IN
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
    LOOP
        result_file := '/tmp/analysis_' || schema_name || '_' ||
                      to_char(now(), 'YYYY-MM-DD') || '.sarif';

        RAISE NOTICE 'Analyzing schema: %', schema_name;

        -- Focus analysis on specific schema
        -- (Note: This would require schema-specific rules in future versions)
        PERFORM pglinter.perform_table_check(result_file);

        RAISE NOTICE 'Results saved to: %', result_file;
    END LOOP;
END $$;
```

### Performance Optimization

```sql
-- performance_focused.sql - Only run performance-related rules
SELECT pglinter.disable_rule(rule_code)
FROM pglinter.show_rules()
WHERE rule_code NOT IN ('B002', 'B004', 'T003', 'T005', 'T007');

-- Run analysis
SELECT pglinter.perform_base_check('/tmp/performance_analysis.sarif');
SELECT pglinter.perform_table_check('/tmp/table_performance.sarif');
```
