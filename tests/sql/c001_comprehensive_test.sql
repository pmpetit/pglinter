-- Comprehensive test for pglinter C001 rule: Memory configuration check
-- This script tests various memory configuration scenarios by changing work_mem session settings

BEGIN;

-- Create the extension and test C001 rule
DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION IF NOT EXISTS pglinter;

SELECT 'Testing C001 rule - Memory configuration safety checks with session changes...' as test_info;

-- First, disable all rules to isolate C001 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only C001 for focused testing
SELECT pglinter.enable_rule('C001') AS c001_enabled;

-- Verify C001 is enabled
SELECT pglinter.is_rule_enabled('C001') AS c001_status;

-- Test 1: Baseline - Current system configuration
SELECT '=== Test 1: Baseline Configuration ===' as test_section;
SELECT current_setting('max_connections')::int as original_max_connections,
       current_setting('work_mem') as original_work_mem;
SELECT pglinter.perform_cluster_check();

-- Test 2: CRITICAL scenario - Should trigger ERROR (>8GB potential)
SELECT '=== Test 2: CRITICAL Scenario (Expected: ERROR) ===' as test_section;
-- Calculate work_mem needed to exceed 8GB with current max_connections
WITH current_config AS (
    SELECT current_setting('max_connections')::int as max_conn
)
SELECT 'Using current max_connections: ' || max_conn ||
       '. Setting work_mem to create >8GB potential usage.' as info
FROM current_config;

SET work_mem = '512MB'; -- This should trigger ERROR with most reasonable max_connections values
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 512MB = ' ||
       (current_setting('max_connections')::int * 512 * 4) || 'MB (' ||
       ROUND((current_setting('max_connections')::int * 512 * 4)::numeric / 1024, 1) || 'GB) potential' as calculation;
SELECT current_setting('max_connections')::int as test_max_connections,
       current_setting('work_mem') as test_work_mem;
SELECT pglinter.perform_cluster_check();

-- Test 3: HIGH scenario - Should trigger WARNING (>4GB potential)
SELECT '=== Test 3: HIGH Scenario (Expected: WARNING) ===' as test_section;
SET work_mem = '128MB'; -- Should trigger WARNING for most configurations
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 128MB = ' ||
       (current_setting('max_connections')::int * 128 * 4) || 'MB (' ||
       ROUND((current_setting('max_connections')::int * 128 * 4)::numeric / 1024, 1) || 'GB) potential' as calculation;
SELECT current_setting('max_connections')::int as test_max_connections,
       current_setting('work_mem') as test_work_mem;
SELECT pglinter.perform_cluster_check();

-- Test 4: MODERATE scenario - Should trigger WARNING (>2GB potential)
SELECT '=== Test 4: MODERATE Scenario (Expected: WARNING) ===' as test_section;
SET work_mem = '64MB'; -- Should trigger WARNING for most configurations (>2GB)
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 64MB = ' ||
       (current_setting('max_connections')::int * 64 * 4) || 'MB (' ||
       ROUND((current_setting('max_connections')::int * 64 * 4)::numeric / 1024, 1) || 'GB) potential' as calculation;
SELECT current_setting('max_connections')::int as test_max_connections,
       current_setting('work_mem') as test_work_mem;
SELECT pglinter.perform_cluster_check();

-- Test 5: MODERATE LOW scenario - Should trigger WARNING or be safe depending on max_connections
SELECT '=== Test 5: MODERATE LOW Scenario ===' as test_section;
SET work_mem = '16MB'; -- Should be safer but may still trigger WARNING
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 16MB = ' ||
       (current_setting('max_connections')::int * 16 * 4) || 'MB (' ||
       ROUND((current_setting('max_connections')::int * 16 * 4)::numeric / 1024, 1) || 'GB) potential' as calculation;
SELECT current_setting('max_connections')::int as test_max_connections,
       current_setting('work_mem') as test_work_mem;
SELECT pglinter.perform_cluster_check();

-- Test 6: SAFE scenario - Should pass (reasonable configuration)
SELECT '=== Test 6: SAFE Scenario (Expected: No issues) ===' as test_section;
SET work_mem = '4MB'; -- Should be safe for most configurations
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 4MB = ' ||
       (current_setting('max_connections')::int * 4 * 4) || 'MB (' ||
       ROUND((current_setting('max_connections')::int * 4 * 4)::numeric / 1024, 1) || 'GB) potential' as calculation;
SELECT current_setting('max_connections')::int as test_max_connections,
       current_setting('work_mem') as test_work_mem;
SELECT pglinter.perform_cluster_check();

-- Test 7: Edge case - Boundary testing (calculating based on current max_connections)
SELECT '=== Test 7: Boundary Testing ===' as test_section;

-- Calculate work_mem that would give exactly 2GB (2048MB) potential usage
WITH threshold_calc AS (
    SELECT
        current_setting('max_connections')::int as max_conn,
        -- Calculate work_mem needed for exactly 2048MB: 2048 / (max_conn * 4)
        ROUND(2048.0 / (current_setting('max_connections')::int * 4), 0) as work_mem_for_2gb
)
SELECT 'For exactly 2GB threshold with ' || max_conn || ' connections, work_mem would need to be ~' ||
       work_mem_for_2gb || 'MB' as threshold_info
FROM threshold_calc;

-- Test just under 2GB threshold
SET work_mem = '4MB'; -- Should be safe for most configurations
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 4MB = ' ||
       (current_setting('max_connections')::int * 4 * 4) || 'MB (should be under 2GB threshold)' as calculation;
SELECT pglinter.perform_cluster_check();

-- Test at a higher value that might trigger warning
SET work_mem = '8MB';
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 8MB = ' ||
       (current_setting('max_connections')::int * 8 * 4) || 'MB' as calculation;
SELECT pglinter.perform_cluster_check();

-- Test 8: Different memory unit formats
SELECT '=== Test 8: Memory Unit Format Testing ===' as test_section;

-- Test kB format
SET work_mem = '8192kB'; -- 8MB
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 8192kB (8MB) = ' ||
       (current_setting('max_connections')::int * 8 * 4) || 'MB' as calculation;
SELECT pglinter.perform_cluster_check();

-- Test GB format (should trigger error with most configurations)
SET work_mem = '1GB'; -- 1024MB
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 1GB (1024MB) = ' ||
       (current_setting('max_connections')::int * 1024 * 4) || 'MB (' ||
       ROUND((current_setting('max_connections')::int * 1024 * 4)::numeric / 1024, 1) || 'GB)' as calculation;
SELECT pglinter.perform_cluster_check();

-- Test bytes format
SET work_mem = '16777216'; -- 16MB in bytes
SELECT 'Configuration: ' || current_setting('max_connections') || ' connections × 16777216 bytes (16MB) = ' ||
       (current_setting('max_connections')::int * 16 * 4) || 'MB' as calculation;
SELECT pglinter.perform_cluster_check();

-- Test 9: Rule management verification
SELECT '=== Test 9: Rule Management ===' as test_section;

-- Test explain rule
SELECT pglinter.explain_rule('C001') as rule_explanation;

-- Test disable/enable
SELECT pglinter.disable_rule('C001') as c001_disabled;
SELECT pglinter.is_rule_enabled('C001') as enabled_after_disable;

-- Should not trigger any checks when disabled
SET work_mem = '1GB'; -- Use a value that would normally trigger ERROR
SELECT 'Testing with disabled C001 and work_mem=1GB (should show no C001 issues)...' as disabled_test;
SELECT pglinter.perform_cluster_check();

-- Re-enable and test again
SELECT pglinter.enable_rule('C001') as c001_re_enabled;
SELECT pglinter.is_rule_enabled('C001') as enabled_after_enable;
SELECT 'Testing with re-enabled C001 and work_mem=1GB (should show C001 issues again)...' as enabled_test;
SELECT pglinter.perform_cluster_check();

ROLLBACK;
