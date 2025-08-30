-- Test for S001 and S002 schema rules
BEGIN;

DROP EXTENSION IF EXISTS pglinter CASCADE;

-- Create test schemas that should trigger S002 (environment prefixes/suffixes)
CREATE SCHEMA prod_sales;
CREATE SCHEMA dev_analytics;
CREATE SCHEMA testing_data;
CREATE SCHEMA reports_staging;

-- Create a clean schema that should not trigger rules
CREATE SCHEMA business_logic;

-- Create some objects in the schemas to make them more realistic
CREATE TABLE prod_sales.customers (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE dev_analytics.metrics (
    id SERIAL PRIMARY KEY,
    metric_name TEXT NOT NULL,
    value NUMERIC
);

CREATE TABLE business_logic.rules (
    id SERIAL PRIMARY KEY,
    rule_name TEXT NOT NULL
);

CREATE EXTENSION IF NOT EXISTS pglinter;

-- Test the schema rules
SELECT 'Testing schema rules S001 and S002...' as test_info;

-- Run schema check to detect environment-named schemas and default privilege issues
SELECT pglinter.perform_schema_check();

-- Test individual schema rules
SELECT pglinter.explain_rule('S001');
SELECT pglinter.explain_rule('S002');

-- Test rule management for schema rules
SELECT pglinter.is_rule_enabled('S001') AS s001_enabled;
SELECT pglinter.is_rule_enabled('S002') AS s002_enabled;

-- Test disabling S002 (environment prefixes)
SELECT pglinter.disable_rule('S002') AS s002_disabled;
SELECT pglinter.perform_schema_check(); -- Should skip S002

-- Re-enable S002
SELECT pglinter.enable_rule('S002') AS s002_reenabled;
SELECT pglinter.perform_schema_check(); -- Should include S002 again

-- Test the comprehensive check including schemas
SELECT pglinter.check_all();

-- Clean up schemas
DROP SCHEMA prod_sales CASCADE;
DROP SCHEMA dev_analytics CASCADE;
DROP SCHEMA testing_data CASCADE;
DROP SCHEMA reports_staging CASCADE;
DROP SCHEMA business_logic CASCADE;

ROLLBACK;
