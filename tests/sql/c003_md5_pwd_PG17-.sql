-- Comprehensive test for pglinter C003 rule: MD5 encrypted passwords
-- This script tests the detection of MD5 password encryption which is deprecated and insecure
-- Note: MD5 password encryption was removed in PostgreSQL 18

CREATE EXTENSION pglinter;

\pset pager off

SELECT 'Testing C003 rule - MD5 password encryption checks...' AS test_info;

-- First, disable all rules to isolate C003 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only C003 for focused testing
SELECT pglinter.enable_rule('C003') AS c003_enabled;

-- Verify C003 is enabled
SELECT pglinter.is_rule_enabled('C003') AS c003_status;

-- Test 1: Check current password_encryption setting
SELECT '=== Test 1: Current password_encryption setting ===' AS test_section;
SELECT name, setting, context
FROM pg_settings
WHERE name = 'password_encryption';

-- Test 2: Run C003 check with current settings
SELECT '=== Test 2: C003 Rule Execution ===' AS test_section;
SELECT pglinter.perform_cluster_check();

-- Test 3: Rule explanation
SELECT '=== Test 3: C003 Rule Explanation ===' AS test_section;
SELECT pglinter.explain_rule('C003') AS rule_explanation;

-- Test 4: Rule details
SELECT '=== Test 4: C003 Rule Details ===' AS test_section;
SELECT code, name, description, message, fixes
FROM pglinter.rules
WHERE code = 'C003';

-- Test 5: Show the actual query used by C003
SELECT '=== Test 5: C003 Query Details ===' AS test_section;
SELECT code, q1 as query
FROM pglinter.rules
WHERE code = 'C003';

-- Test 6: Manual execution of C003 query to understand results
SELECT '=== Test 6: Manual C003 Query Execution ===' AS test_section;
SELECT count(*) as md5_password_count
FROM pg_catalog.pg_settings
WHERE name='password_encryption' AND setting='md5';

-- Test 7: Export results to SARIF format
SELECT '=== Test 7: Export to SARIF ===' AS test_section;
SELECT pglinter.check('/tmp/pglinter_c003_results.sarif');

-- Show checksum of generated file if it exists
\! test -f /tmp/pglinter_c003_results.sarif && md5sum /tmp/pglinter_c003_results.sarif || echo "SARIF file not generated"


DROP EXTENSION pglinter CASCADE;
