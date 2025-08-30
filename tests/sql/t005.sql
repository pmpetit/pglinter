-- Test for T005 rule - Tables with potential missing indexes (high sequential scan usage)
BEGIN;

DROP EXTENSION IF EXISTS pglinter CASCADE;

-- Create test table that will likely have high sequential scans
CREATE TABLE test_table_seq_scan (
    id INT,
    name TEXT,
    category TEXT,
    value NUMERIC
);

-- Insert some test data to make the table more realistic
INSERT INTO test_table_seq_scan (id, name, category, value)
SELECT i, 'name_' || i, 'category_' || (i % 10), random() * 1000
FROM generate_series(1, 1000) i;

-- Create another table with proper indexing
CREATE TABLE test_table_indexed (
    id SERIAL PRIMARY KEY,
    name TEXT,
    category TEXT,
    value NUMERIC
);

-- Add indexes to prevent high sequential scans
CREATE INDEX idx_category ON test_table_indexed(category);
CREATE INDEX idx_value ON test_table_indexed(value);

-- Insert data
INSERT INTO test_table_indexed (name, category, value)
SELECT 'name_' || i, 'category_' || (i % 10), random() * 1000
FROM generate_series(1, 1000) i;

CREATE EXTENSION IF NOT EXISTS pglinter;

-- Force some statistics collection
ANALYZE test_table_seq_scan;
ANALYZE test_table_indexed;

-- Simulate some queries that would cause sequential scans
SELECT COUNT(*) FROM test_table_seq_scan WHERE category = 'category_1';
SELECT COUNT(*) FROM test_table_seq_scan WHERE value > 500;

-- Simulate indexed queries (should not cause seq scans)
SELECT COUNT(*) FROM test_table_indexed WHERE category = 'category_1';
SELECT COUNT(*) FROM test_table_indexed WHERE value > 500;

-- Test the T005 rule
SELECT 'Testing T005 rule...' as test_info;

-- Run table check to detect high sequential scan usage
SELECT pglinter.perform_table_check();

-- Test rule management for T005
SELECT pglinter.explain_rule('T005');
SELECT pglinter.is_rule_enabled('T005') AS t005_enabled;

-- Test disabling T005
SELECT pglinter.disable_rule('T005') AS t005_disabled;
SELECT pglinter.perform_table_check(); -- Should skip T005

-- Re-enable T005
SELECT pglinter.enable_rule('T005') AS t005_reenabled;
SELECT pglinter.perform_table_check(); -- Should include T005 again

-- Clean up
DROP TABLE test_table_seq_scan CASCADE;
DROP TABLE test_table_indexed CASCADE;

ROLLBACK;
