-- Test for pglinter T002 rule: Tables with redundant indexes

\pset pager off

-- Create test tables with redundant indexes for T002 testing
CREATE TABLE IF NOT EXISTS customers_with_redundant_idx (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create another table for more redundant index scenarios
CREATE TABLE IF NOT EXISTS products_with_redundant_idx (
    product_id SERIAL PRIMARY KEY,
    sku VARCHAR(50),
    name VARCHAR(255),
    category VARCHAR(100),
    price DECIMAL(10,2),
    stock_quantity INT,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create a third table to test multiple tables with redundant indexes
CREATE TABLE IF NOT EXISTS orders_with_redundant_idx (
    order_id SERIAL PRIMARY KEY,
    customer_id INT,
    product_id INT,
    quantity INT,
    order_date DATE,
    status VARCHAR(50),
    total_amount DECIMAL(10,2)
);

-- Case 1: Exact duplicate indexes on customers table
CREATE INDEX idx_customers_email_1 ON customers_with_redundant_idx (email);
CREATE INDEX idx_customers_email_2 ON customers_with_redundant_idx (email);

-- Case 2: Same composite index created twice on customers table
CREATE INDEX idx_customers_name_1 ON customers_with_redundant_idx (first_name, last_name);
CREATE INDEX idx_customers_name_2 ON customers_with_redundant_idx (first_name, last_name);

-- Case 3: Redundant indexes on products table
CREATE INDEX idx_products_sku_1 ON products_with_redundant_idx (sku);
CREATE INDEX idx_products_sku_2 ON products_with_redundant_idx (sku);

-- Case 4: Complex composite index redundancy on products table
CREATE INDEX idx_products_category_active_1 ON products_with_redundant_idx (category, is_active);
CREATE INDEX idx_products_category_active_2 ON products_with_redundant_idx (category, is_active);

-- Case 5: Redundant indexes on orders table
CREATE INDEX idx_orders_customer_1 ON orders_with_redundant_idx (customer_id);
CREATE INDEX idx_orders_customer_2 ON orders_with_redundant_idx (customer_id);

-- Case 6: Different composite index redundancy on orders table
CREATE INDEX idx_orders_date_status_1 ON orders_with_redundant_idx (order_date, status);
CREATE INDEX idx_orders_date_status_2 ON orders_with_redundant_idx (order_date, status);

-- Case 7: Add some non-redundant indexes to ensure they don't trigger the rule
CREATE INDEX idx_customers_phone ON customers_with_redundant_idx (phone);
CREATE INDEX idx_products_price ON products_with_redundant_idx (price);
CREATE INDEX idx_orders_total ON orders_with_redundant_idx (total_amount);

CREATE EXTENSION IF NOT EXISTS pglinter;

-- First, disable all rules to isolate T002 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only T002 for focused testing
SELECT pglinter.enable_rule('T002') AS T002_enabled;

-- Test with file output
SELECT pglinter.perform_table_check('/tmp/pglinter_T002_results.sarif');

-- Test if file exists and show checksum
\! md5sum /tmp/pglinter_T002_results.sarif

-- Test with no output file (should output to prompt)
SELECT pglinter.perform_table_check();

-- Test rule management for T002
SELECT pglinter.explain_rule('T002');

-- Show that T002 is enabled
SELECT pglinter.is_rule_enabled('T002') AS T002_enabled;

-- Disable T002 temporarily and test
SELECT pglinter.disable_rule('T002') AS T002_disabled;
SELECT pglinter.perform_table_check();

-- Re-enable T002 and test again
SELECT pglinter.enable_rule('T002') AS T002_re_enabled;
SELECT pglinter.perform_table_check();

-- Clean up test tables
DROP TABLE IF EXISTS customers_with_redundant_idx CASCADE;
DROP TABLE IF EXISTS products_with_redundant_idx CASCADE;
DROP TABLE IF EXISTS orders_with_redundant_idx CASCADE;

