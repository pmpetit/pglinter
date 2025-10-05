-- Test for pglinter B001 rule with file output
CREATE EXTENSION pglinter;

CREATE TABLE my_table_without_pk (
    id INT,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE,
    query TEXT,
    warning_level INT,
    error_level INT,
    scope TEXT
);

-- Disable all rules first
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Run table check to detect tables without PK
SELECT pglinter.perform_table_check();

-- Test rule management for B001
SELECT pglinter.explain_rule('B001');
SELECT pglinter.is_rule_enabled('B001') AS is_b001_enabled;

-- Test with file output
SELECT pglinter.perform_base_check('/tmp/pglinter_base_results.sarif');

-- Test if file exists
\! md5sum /tmp/pglinter_base_results.sarif

-- Test with no output file (should output to prompt)
SELECT pglinter.perform_base_check();

-- Re-enable B001 rule
SELECT pglinter.enable_rule('B001') AS enable_b001;

-- Test again with B001 enabled
SELECT pglinter.perform_base_check();

-- Test with file output
SELECT pglinter.perform_base_check('/tmp/pglinter_base_results.sarif');

-- Test if file exists
\! md5sum /tmp/pglinter_base_results.sarif

DROP TABLE my_table_without_pk CASCADE;

DROP EXTENSION pglinter CASCADE;
