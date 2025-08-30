-- Demo script for the new rule level management functions
-- This script demonstrates how to get and update warning_level and error_level for rules

\echo 'Testing rule level management functions...'

-- First, let's see the current levels for T005
\echo 'Current T005 rule levels:'
SELECT pglinter.get_rule_levels('T005') as current_levels;

-- Let's also check a few other rules
\echo 'Current levels for some rules:'
SELECT
    code,
    pglinter.get_rule_levels(code) as levels
FROM pglinter.list_rules()
WHERE code IN ('B001', 'T001', 'T005', 'C001')
ORDER BY code;

-- Update T005 to have different thresholds
\echo 'Updating T005 warning level to 25 and error level to 75:'
SELECT pglinter.update_rule_levels('T005', 25, 75) as update_success;

-- Verify the update
\echo 'T005 levels after update:'
SELECT pglinter.get_rule_levels('T005') as updated_levels;

-- Update only the warning level of B001
\echo 'Updating only B001 warning level to 5:'
SELECT pglinter.update_rule_levels('B001', 5, NULL) as update_success;

-- Verify B001 update
\echo 'B001 levels after warning level update:'
SELECT pglinter.get_rule_levels('B001') as updated_levels;

-- Update only the error level of T001
\echo 'Updating only T001 error level to 3:'
SELECT pglinter.update_rule_levels('T001', NULL, 3) as update_success;

-- Verify T001 update
\echo 'T001 levels after error level update:'
SELECT pglinter.get_rule_levels('T001') as updated_levels;

-- Try to update a non-existent rule
\echo 'Trying to update non-existent rule (should return false):'
SELECT pglinter.update_rule_levels('NONEXISTENT', 10, 20) as should_be_false;

-- Show all updated levels
\echo 'All rule levels after updates:'
SELECT
    code,
    pglinter.get_rule_levels(code) as levels
FROM pglinter.list_rules()
ORDER BY code;

-- You can also query the rules table directly to see the raw values
\echo 'Raw warning_level and error_level from rules table:'
SELECT code, name, warning_level, error_level, enable
FROM pglinter.rules
WHERE code IN ('B001', 'T001', 'T005', 'C001')
ORDER BY code;

\echo 'Rule level management demo completed!'
\echo ''
\echo 'Usage Summary:'
\echo '  - Get levels: SELECT pglinter.get_rule_levels(''RULE_CODE'');'
\echo '  - Update both: SELECT pglinter.update_rule_levels(''RULE_CODE'', warning, error);'
\echo '  - Update warning only: SELECT pglinter.update_rule_levels(''RULE_CODE'', warning, NULL);'
\echo '  - Update error only: SELECT pglinter.update_rule_levels(''RULE_CODE'', NULL, error);'
\echo ''
\echo 'Note: Changes affect rule behavior immediately. Higher values mean more permissive thresholds.'
