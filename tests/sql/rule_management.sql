-- Test for pg_linter rule management functionality
BEGIN;

DROP EXTENSION IF EXISTS pg_linter CASCADE;

CREATE TABLE IF NOT EXISTS test_table_for_rules (
    id INT,
    name TEXT
);

CREATE EXTENSION IF NOT EXISTS pg_linter;

-- Show initial rule status
SELECT pg_linter.show_rules();

-- Test enabling and disabling a specific rule
SELECT pg_linter.is_rule_enabled('B001') AS b001_initially_enabled;

-- Disable B001 rule
SELECT pg_linter.disable_rule('B001') AS b001_disabled;

-- Check if it's disabled
SELECT pg_linter.is_rule_enabled('B001') AS b001_after_disable;

-- Run base check (should skip B001)
SELECT pg_linter.perform_base_check();

-- Re-enable B001 rule
SELECT pg_linter.enable_rule('B001') AS b001_enabled;

-- Check if it's enabled again
SELECT pg_linter.is_rule_enabled('B001') AS b001_after_enable;

-- Test with non-existent rule
SELECT pg_linter.disable_rule('NONEXISTENT') AS nonexistent_disable;

-- Show final rule status
SELECT pg_linter.show_rules();

ROLLBACK;
