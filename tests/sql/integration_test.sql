-- Comprehensive integration test for pglinter
-- Tests multiple rules across all categories (B, C, T, S series)
BEGIN;

DROP EXTENSION IF EXISTS pglinter CASCADE;

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

CREATE INDEX idx_name_1 ON products (name);
CREATE INDEX idx_name_2 ON products (name); -- redundant
CREATE INDEX idx_composite_1 ON products (category, price);
CREATE INDEX idx_composite_2 ON products (category, price); -- redundant

-- 3. Foreign keys without indexes (B003, T004)
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT,
    product_id INT,
    total NUMERIC
);

-- Add foreign keys without creating indexes
ALTER TABLE orders ADD CONSTRAINT fk_user
FOREIGN KEY (user_id) REFERENCES users_no_pk (id);
ALTER TABLE orders ADD CONSTRAINT fk_product
FOREIGN KEY (product_id) REFERENCES products (id);

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
CREATE EXTENSION IF NOT EXISTS pglinter;

-- Run comprehensive analysis
SELECT '=== COMPREHENSIVE pglinter ANALYSIS ===' AS info;

-- Test all rule categories
SELECT 'BASE RULES:' AS category;
SELECT pglinter.perform_base_check();

SELECT 'TABLE RULES:' AS category;
SELECT pglinter.perform_table_check();

SELECT 'SCHEMA RULES:' AS category;
SELECT pglinter.perform_schema_check();

SELECT 'CLUSTER RULES:' AS category;
SELECT pglinter.perform_cluster_check();

-- Test comprehensive check
SELECT 'COMPREHENSIVE CHECK:' AS category;
SELECT pglinter.check_all();

-- Test rule management features
SELECT '=== RULE MANAGEMENT ===' AS info;

-- Show all rules
SELECT pglinter.show_rules();

-- Test some explanations
SELECT pglinter.explain_rule('B001');
SELECT pglinter.explain_rule('T003');
SELECT pglinter.explain_rule('S002');

-- Test output to file functionality
SELECT '=== OUTPUT TO FILE TEST ===' AS info;
SELECT pglinter.perform_base_check('/tmp/integration_base.sarif');
SELECT pglinter.perform_table_check('/tmp/integration_table.sarif');
SELECT pglinter.perform_schema_check('/tmp/integration_schema.sarif');

-- Test rule disable/enable functionality
SELECT '=== RULE TOGGLE TEST ===' AS info;

-- Disable some rules
SELECT pglinter.disable_rule('B001');
SELECT pglinter.disable_rule('T003');

-- Run checks (should skip disabled rules)
SELECT pglinter.perform_base_check();
SELECT pglinter.perform_table_check();

-- Re-enable rules
SELECT pglinter.enable_rule('B001');
SELECT pglinter.enable_rule('T003');

-- Final comprehensive check
SELECT pglinter.check_all();

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
