-- Test for T003 rule - Tables with redundant indexes
BEGIN;

DROP EXTENSION IF EXISTS pglinter CASCADE;

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

CREATE EXTENSION IF NOT EXISTS pglinter;

-- Test the T003 rule specifically
SELECT 'Testing T003 rule...' as test_info;

-- Run table check to see redundant indexes
SELECT pglinter.perform_table_check();

-- Test rule management
SELECT pglinter.explain_rule('T003');

-- Test enabling/disabling T003
SELECT pglinter.is_rule_enabled('T003') AS t003_initially_enabled;
SELECT pglinter.disable_rule('T003') AS t003_disabled;
SELECT pglinter.is_rule_enabled('T003') AS t003_after_disable;

-- Run check again (should skip T003)
SELECT pglinter.perform_table_check();

-- Re-enable T003
SELECT pglinter.enable_rule('T003') AS t003_enabled;
SELECT pglinter.is_rule_enabled('T003') AS t003_after_enable;

-- Final check with T003 enabled
SELECT pglinter.perform_table_check();

-- Clean up
DROP TABLE test_table_redundant CASCADE;
DROP TABLE test_table_clean CASCADE;

ROLLBACK;
