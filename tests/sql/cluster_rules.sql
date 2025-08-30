-- Test for C001 and C002 cluster rules
BEGIN;

DROP EXTENSION IF EXISTS pglinter CASCADE;

CREATE EXTENSION IF NOT EXISTS pglinter;

-- Test cluster rules
SELECT 'Testing cluster rules C001 and C002...' as test_info;

-- C001: Memory configuration issues
-- This rule checks max_connections and work_mem settings
-- It will analyze current PostgreSQL configuration
SELECT 'Current PostgreSQL configuration:' as info;
SELECT current_setting('max_connections') as max_connections;
SELECT current_setting('work_mem') as work_mem;

-- C002: Insecure pg_hba.conf entries
-- This rule checks for insecure authentication methods
-- Note: This may not trigger in test environment

-- Run cluster check
SELECT pglinter.perform_cluster_check();

-- Test rule management for cluster rules
SELECT pglinter.explain_rule('C001');
SELECT pglinter.explain_rule('C002');

-- Test enabling/disabling cluster rules
SELECT pglinter.is_rule_enabled('C001') AS c001_enabled;
SELECT pglinter.is_rule_enabled('C002') AS c002_enabled;

-- Disable C001 temporarily
SELECT pglinter.disable_rule('C001') AS c001_disabled;
SELECT pglinter.perform_cluster_check(); -- Should skip C001

-- Re-enable C001
SELECT pglinter.enable_rule('C001') AS c001_reenabled;
SELECT pglinter.perform_cluster_check(); -- Should include C001 again

-- Test output to file for cluster rules
SELECT pglinter.perform_cluster_check('/tmp/cluster_test.sarif');

-- Show all cluster-related information
SELECT 'Cluster configuration summary:' as info;
SELECT
    current_setting('max_connections') as max_connections,
    current_setting('work_mem') as work_mem,
    current_setting('shared_buffers') as shared_buffers,
    current_setting('effective_cache_size') as effective_cache_size;

ROLLBACK;
