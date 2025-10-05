-- Test for pglinter B002 rule: Redundant indexes
CREATE EXTENSION pglinter;

-- Create test tables with redundant indexes
CREATE TABLE test_table_with_redundant_indexes (
    id INT PRIMARY KEY,
    name TEXT,
    email VARCHAR(255),
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);


-- Create table with one index and a unique constrainte on the same column
CREATE TABLE orders_table_with_constraint (
    order_id SERIAL PRIMARY KEY,
    customer_id INT UNIQUE,
    product_name VARCHAR(255),
    order_date DATE,
    amount DECIMAL(10, 2)
);

-- Create an index that is redundant with the unique constraint
CREATE INDEX my_idx_customer ON orders_table_with_constraint (customer_id);

-- Create another table for more redundant index scenarios
CREATE TABLE orders_table (
    order_id SERIAL PRIMARY KEY,
    customer_id INT,
    product_name VARCHAR(255),
    order_date DATE,
    amount DECIMAL(10, 2)
);

-- Create redundant indexes to trigger B002 rule
-- Case 1: Exact duplicate indexes on same columns
CREATE INDEX idx_name_1 ON test_table_with_redundant_indexes (name);
CREATE INDEX idx_name_2 ON test_table_with_redundant_indexes (name, created_at);
CREATE INDEX idx_name_3 ON test_table_with_redundant_indexes (
    name, created_at, email
);

-- Case 2: Multiple indexes on same composite key
CREATE INDEX idx_email_status_1 ON test_table_with_redundant_indexes (
    email, status
);
CREATE INDEX idx_email_status_2 ON test_table_with_redundant_indexes (
    email, status, created_at
);

-- Case 3: Redundant indexes on the orders table
CREATE INDEX idx_customer_1 ON orders_table (order_id);

-- Case 3-bis: Non Redundant indexes on the orders table
CREATE INDEX idx_customer_2 ON orders_table (customer_id, order_id);

-- Case 4: Composite index redundancy
CREATE INDEX idx_customer_date_1 ON orders_table (product_name, order_date);
CREATE INDEX idx_customer_date_2 ON orders_table (product_name, order_date);

-- First, disable all rules to isolate B001 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B002 for focused testing
SELECT pglinter.enable_rule('B002') AS b001_enabled;

-- Test with file output
SELECT pglinter.perform_base_check('/tmp/pglinter_b002_results.sarif');

-- Test if file exists and show checksum
\! md5sum /tmp/pglinter_b002_results.sarif

-- Test with no output file (should output to prompt)
SELECT pglinter.perform_base_check();

-- Test rule management for B002
SELECT pglinter.explain_rule('B002');

-- Show that B002 is enabled
SELECT pglinter.is_rule_enabled('B002') AS b002_enabled;

-- Disable B002 temporarily and test
SELECT pglinter.disable_rule('B002') AS b002_disabled;
SELECT pglinter.perform_base_check();

DROP TABLE orders_table CASCADE;
DROP TABLE orders_table_with_constraint CASCADE;
DROP TABLE test_table_with_redundant_indexes CASCADE;

DROP EXTENSION pglinter CASCADE;
