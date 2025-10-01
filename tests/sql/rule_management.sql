-- Test for pglinter rule management functionality
CREATE EXTENSION pglinter;

BEGIN;

CREATE TABLE IF NOT EXISTS test_table_for_rules (
    id INT,
    name TEXT
);

-- Show initial rule status
SELECT pglinter.show_rules();

-- Test enabling and disabling a specific rule
SELECT pglinter.is_rule_enabled('B001') AS b001_initially_enabled;

-- Disable B001 rule
SELECT pglinter.disable_rule('B001') AS b001_disabled;

-- Check if it's disabled
SELECT pglinter.is_rule_enabled('B001') AS b001_after_disable;

-- Run base check (should skip B001)
SELECT pglinter.perform_base_check();

-- Re-enable B001 rule
SELECT pglinter.enable_rule('B001') AS b001_enabled;

-- Check if it's enabled again
SELECT pglinter.is_rule_enabled('B001') AS b001_after_enable;

-- Test with non-existent rule
SELECT pglinter.disable_rule('NONEXISTENT') AS nonexistent_disable;

-- Show final rule status
SELECT pglinter.show_rules();

ROLLBACK;

DROP EXTENSION pglinter CASCADE;
