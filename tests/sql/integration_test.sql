-- Comprehensive integration test for pg_linter
-- Tests multiple rules across all categories (B, C, T, S series)
BEGIN;

DROP EXTENSION IF EXISTS pg_linter CASCADE;

-- Create various test scenarios to trigger multiple rules

-- 1. Tables without primary keys (B001, T001)
CREATE TABLE users_no_pk (
    id INT,
    username TEXT,
    email TEXT
);

-- 2. Redundant indexes (B002, T003)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    category TEXT,
    price NUMERIC
);

CREATE INDEX idx_name_1 ON products(name);
CREATE INDEX idx_name_2 ON products(name); -- redundant
CREATE INDEX idx_composite_1 ON products(category, price);
CREATE INDEX idx_composite_2 ON products(category, price); -- redundant

-- 3. Foreign keys without indexes (B003, T004)
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT,
    product_id INT,
    total NUMERIC
);

-- Add foreign keys without creating indexes
ALTER TABLE orders ADD CONSTRAINT fk_user
    FOREIGN KEY (user_id) REFERENCES users_no_pk(id);
ALTER TABLE orders ADD CONSTRAINT fk_product
    FOREIGN KEY (product_id) REFERENCES products(id);

-- 4. Tables with uppercase names/columns (B006, T011)
CREATE TABLE "UPPERCASE_ISSUES" (
    id SERIAL PRIMARY KEY,
    "UPPER_NAME" TEXT,
    "DESCRIPTION" TEXT
);

-- 5. Reserved keywords (T010)
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    "SELECT" TEXT, -- reserved keyword
    "FROM" TEXT,   -- reserved keyword
    description TEXT
);

-- 6. Environment-prefixed schemas (S002)
CREATE SCHEMA prod_analytics;
CREATE SCHEMA dev_reports;
CREATE SCHEMA staging_data;

-- Add some tables to the schemas
CREATE TABLE prod_analytics.metrics (
    id SERIAL PRIMARY KEY,
    metric_name TEXT
);

CREATE TABLE dev_reports.summaries (
    id SERIAL PRIMARY KEY,
    report_data TEXT
);

-- Create extension
CREATE EXTENSION IF NOT EXISTS pg_linter;

-- Run comprehensive analysis
SELECT '=== COMPREHENSIVE pg_linter ANALYSIS ===' as info;

-- Test all rule categories
SELECT 'BASE RULES:' as category;
SELECT pg_linter.perform_base_check();

SELECT 'TABLE RULES:' as category;
SELECT pg_linter.perform_table_check();

SELECT 'SCHEMA RULES:' as category;
SELECT pg_linter.perform_schema_check();

SELECT 'CLUSTER RULES:' as category;
SELECT pg_linter.perform_cluster_check();

-- Test comprehensive check
SELECT 'COMPREHENSIVE CHECK:' as category;
SELECT pg_linter.check_all();

-- Test rule management features
SELECT '=== RULE MANAGEMENT ===' as info;

-- Show all rules
SELECT pg_linter.show_rules();

-- Test some explanations
SELECT pg_linter.explain_rule('B001');
SELECT pg_linter.explain_rule('T003');
SELECT pg_linter.explain_rule('S002');

-- Test output to file functionality
SELECT '=== OUTPUT TO FILE TEST ===' as info;
SELECT pg_linter.perform_base_check('/tmp/integration_base.sarif');
SELECT pg_linter.perform_table_check('/tmp/integration_table.sarif');
SELECT pg_linter.perform_schema_check('/tmp/integration_schema.sarif');

-- Test rule disable/enable functionality
SELECT '=== RULE TOGGLE TEST ===' as info;

-- Disable some rules
SELECT pg_linter.disable_rule('B001');
SELECT pg_linter.disable_rule('T003');

-- Run checks (should skip disabled rules)
SELECT pg_linter.perform_base_check();
SELECT pg_linter.perform_table_check();

-- Re-enable rules
SELECT pg_linter.enable_rule('B001');
SELECT pg_linter.enable_rule('T003');

-- Final comprehensive check
SELECT pg_linter.check_all();

-- Clean up
DROP SCHEMA prod_analytics CASCADE;
DROP SCHEMA dev_reports CASCADE;
DROP SCHEMA staging_data CASCADE;
DROP TABLE items CASCADE;
DROP TABLE "UPPERCASE_ISSUES" CASCADE;
DROP TABLE orders CASCADE;
DROP TABLE products CASCADE;
DROP TABLE users_no_pk CASCADE;

ROLLBACK;
