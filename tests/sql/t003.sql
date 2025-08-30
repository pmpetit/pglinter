-- Test for T003 rule - Tables with redundant indexes
BEGIN;

DROP EXTENSION IF EXISTS pg_linter CASCADE;

-- Create test table with redundant indexes
CREATE TABLE test_table_redundant (
    id INT,
    name TEXT,
    email TEXT,
    status TEXT
);

-- Create multiple indexes on the same column (redundant)
CREATE INDEX idx_name_1 ON test_table_redundant(name);
CREATE INDEX idx_name_2 ON test_table_redundant(name); -- redundant with idx_name_1

-- Create composite indexes with same columns (redundant)
CREATE INDEX idx_composite_1 ON test_table_redundant(email, status);
CREATE INDEX idx_composite_2 ON test_table_redundant(email, status); -- redundant with idx_composite_1

-- Create another test table
CREATE TABLE test_table_clean (
    id SERIAL PRIMARY KEY,
    description TEXT
);

-- This index is unique, not redundant
CREATE UNIQUE INDEX idx_clean_desc ON test_table_clean(description);

CREATE EXTENSION IF NOT EXISTS pg_linter;

-- Test the T003 rule specifically
SELECT 'Testing T003 rule...' as test_info;

-- Run table check to see redundant indexes
SELECT pg_linter.perform_table_check();

-- Test rule management
SELECT pg_linter.explain_rule('T003');

-- Test enabling/disabling T003
SELECT pg_linter.is_rule_enabled('T003') AS t003_initially_enabled;
SELECT pg_linter.disable_rule('T003') AS t003_disabled;
SELECT pg_linter.is_rule_enabled('T003') AS t003_after_disable;

-- Run check again (should skip T003)
SELECT pg_linter.perform_table_check();

-- Re-enable T003
SELECT pg_linter.enable_rule('T003') AS t003_enabled;
SELECT pg_linter.is_rule_enabled('T003') AS t003_after_enable;

-- Final check with T003 enabled
SELECT pg_linter.perform_table_check();

-- Clean up
DROP TABLE test_table_redundant CASCADE;
DROP TABLE test_table_clean CASCADE;

ROLLBACK;
