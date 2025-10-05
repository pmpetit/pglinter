-- Comprehensive test for pglinter C002 rule: Insecure pg_hba.conf entries
-- This script tests the detection of insecure authentication methods in pg_hba.conf
CREATE EXTENSION pglinter;


\pset pager off

SELECT 'Testing C002 rule - pg_hba.conf security checks...' AS test_info;

-- First, disable all rules to isolate C002 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only C002 for focused testing
SELECT pglinter.enable_rule('C002') AS c002_enabled;

-- Verify C002 is enabled
SELECT pglinter.is_rule_enabled('C002') AS c002_status;

-- Test 1: Run C002 check with current settings
SELECT '=== Test 2: C002 Rule Execution ===' AS test_section;
SELECT pglinter.perform_cluster_check();

-- Test if file exists and show checksum
SELECT pglinter.perform_base_check('/tmp/pglinter_c002_results.sarif');
\! md5sum /tmp/pglinter_c002_results.sarif


-- Test rule explanation
SELECT 'C002 rule explanation:' AS explanation_info;
SELECT pglinter.explain_rule('C002') AS rule_explanation;


DROP EXTENSION pglinter CASCADE;
