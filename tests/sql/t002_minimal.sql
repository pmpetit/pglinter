-- Test for pglinter T002 rule: Tables with redundant indexes (minimal test)

--BEGIN;

DROP TABLE IF EXISTS test_redundant;

-- Create one simple test table
CREATE TABLE test_redundant (
    id INT PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    tel TEXT
);

-- Create two identical indexes (redundant)
CREATE INDEX idx_name_1 ON test_redundant (first_name);
CREATE INDEX idx_name_2 ON test_redundant (first_name,last_name);
CREATE INDEX idx_name_3 ON test_redundant (first_name,last_name,tel);
CREATE INDEX idx_name_4 ON test_redundant (tel,last_name);

DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION IF NOT EXISTS pglinter;

-- Enable only T002
SELECT pglinter.disable_all_rules();
SELECT pglinter.enable_rule('T002');

-- Test T002
SELECT pglinter.perform_table_check();

-- Cleanup
--DROP TABLE test_redundant CASCADE;

--ROLLBACK;
