-- Comprehensive test for pglinter C002 rule: Insecure pg_hba.conf entries
-- This script tests the detection of insecure authentication methods in pg_hba.conf

BEGIN;

\pset pager off

-- Create the extension and test C002 rule
DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION IF NOT EXISTS pglinter;

SELECT 'Testing C002 rule - pg_hba.conf security checks...' as test_info;

-- First, disable all rules to isolate C002 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only C002 for focused testing
SELECT pglinter.enable_rule('C002') AS c002_enabled;

-- Verify C002 is enabled
SELECT pglinter.is_rule_enabled('C002') AS c002_status;

-- Test 1: Run C002 check with current settings
SELECT '=== Test 2: C002 Rule Execution ===' as test_section;
SELECT pglinter.perform_cluster_check();

-- Test rule explanation
SELECT 'C002 rule explanation:' as explanation_info;
SELECT pglinter.explain_rule('C002') as rule_explanation;


ROLLBACK;
