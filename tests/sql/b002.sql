-- Test for pg_linter B002 rule: Redundant indexes
BEGIN;

-- Create test tables with redundant indexes
CREATE TABLE IF NOT EXISTS test_table_with_redundant_indexes (
    id INT PRIMARY KEY,
    name TEXT,
    email VARCHAR(255),
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create another table for more redundant index scenarios
CREATE TABLE IF NOT EXISTS orders_table (
    order_id SERIAL PRIMARY KEY,
    customer_id INT,
    product_name VARCHAR(255),
    order_date DATE,
    amount DECIMAL(10,2)
);

-- Create redundant indexes to trigger B002 rule
-- Case 1: Exact duplicate indexes on same columns
CREATE INDEX idx_name_1 ON test_table_with_redundant_indexes (name);
CREATE INDEX idx_name_2 ON test_table_with_redundant_indexes (name);

-- Case 2: Multiple indexes on same composite key
CREATE INDEX idx_email_status_1 ON test_table_with_redundant_indexes (email, status);
CREATE INDEX idx_email_status_2 ON test_table_with_redundant_indexes (email, status);

-- Case 3: Redundant indexes on the orders table
CREATE INDEX idx_customer_1 ON orders_table (customer_id);
CREATE INDEX idx_customer_2 ON orders_table (customer_id);

-- Case 4: Composite index redundancy
CREATE INDEX idx_customer_date_1 ON orders_table (customer_id, order_date);
CREATE INDEX idx_customer_date_2 ON orders_table (customer_id, order_date);

CREATE EXTENSION IF NOT EXISTS pg_linter;

-- Test with file output
SELECT pg_linter.perform_base_check('/tmp/pg_linter_b002_results.sarif');

-- Test if file exists and show checksum
\! md5sum /tmp/pg_linter_b002_results.sarif

-- Test with no output file (should output to prompt)
SELECT pg_linter.perform_base_check();

-- Test rule management for B002
SELECT pg_linter.explain_rule('B002');

-- Show that B002 is enabled
SELECT pg_linter.is_rule_enabled('B002') AS b002_enabled;

-- Disable B002 temporarily and test
SELECT pg_linter.disable_rule('B002') AS b002_disabled;
SELECT pg_linter.perform_base_check();

-- Re-enable B002
SELECT pg_linter.enable_rule('B002') AS b002_re_enabled;

-- Clean up test tables
DROP TABLE IF EXISTS test_table_with_redundant_indexes CASCADE;
DROP TABLE IF EXISTS orders_table CASCADE;

ROLLBACK;
