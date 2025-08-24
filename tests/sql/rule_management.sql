-- Test for dblinter rule management functionality
BEGIN;

DROP EXTENSION IF EXISTS dblinter CASCADE;

CREATE TABLE IF NOT EXISTS test_table_for_rules (
    id INT,
    name TEXT
);

CREATE EXTENSION IF NOT EXISTS dblinter;

-- Show initial rule status
SELECT dblinter.show_rules();

-- Test enabling and disabling a specific rule
SELECT dblinter.is_rule_enabled('B001') AS b001_initially_enabled;

-- Disable B001 rule
SELECT dblinter.disable_rule('B001') AS b001_disabled;

-- Check if it's disabled
SELECT dblinter.is_rule_enabled('B001') AS b001_after_disable;

-- Run base check (should skip B001)
SELECT dblinter.perform_base_check();

-- Re-enable B001 rule
SELECT dblinter.enable_rule('B001') AS b001_enabled;

-- Check if it's enabled again
SELECT dblinter.is_rule_enabled('B001') AS b001_after_enable;

-- Test with non-existent rule
SELECT dblinter.disable_rule('NONEXISTENT') AS nonexistent_disable;

-- Show final rule status
SELECT dblinter.show_rules();

ROLLBACK;
