-- Quick demonstration of the new rule level management functions
-- Run this in PostgreSQL after installing the updated pglinter extension
CREATE EXTENSION pglinter;

\echo '=== Rule Level Management Demo ==='

-- Show current T005 levels (should be 50, 90 from rules.sql)
\echo 'Current T005 levels:'
SELECT pglinter.get_rule_levels('T005') as current_t005_levels;

-- Update T005 to be more strict (lower thresholds)
\echo 'Making T005 more strict (warning=20, error=40):'
SELECT pglinter.update_rule_levels('T005', 20, 40) as update_success;

-- Verify the change
\echo 'T005 levels after update:'
SELECT pglinter.get_rule_levels('T005') as updated_t005_levels;

-- Check a few other rules
\echo 'Current levels for various rules:'
SELECT
    code,
    warning_level,
    error_level,
    pglinter.get_rule_levels(code) as formatted_levels
FROM pglinter.rules
WHERE code IN ('B001', 'T001', 'T005')
ORDER BY code;

-- Update only warning level for B001
\echo 'Updating only B001 warning level to 5:'
SELECT pglinter.update_rule_levels('B001', 5, NULL) as partial_update;

-- Show the result
\echo 'B001 after partial update:'
SELECT pglinter.get_rule_levels('B001') as b001_levels;

\echo '=== Demo Complete ==='
\echo 'New functions available:'
\echo '  - pglinter.get_rule_levels(rule_code)'
\echo '  - pglinter.update_rule_levels(rule_code, warning_level, error_level)'
\echo ''
\echo 'Use NULL for warning_level or error_level to keep current value unchanged.'

DROP EXTENSION pglinter CASCADE;
