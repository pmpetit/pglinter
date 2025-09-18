-- Simple example to demonstrate unused indexes detection (T006 rule)
-- This script creates tables with indexes, some of which will be unused,
-- and shows how the T006 rule detects unused indexes.


\pset pager off

-- Create tables with various indexes
CREATE TABLE test_products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10, 2),
    description TEXT,
    sku VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00',
    updated_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

CREATE TABLE test_orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    product_id INTEGER REFERENCES test_products (product_id),
    order_date DATE NOT NULL DEFAULT '2024-01-15',
    quantity INTEGER DEFAULT 1,
    total_amount DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT '2024-01-15 14:30:00'
);

CREATE TABLE test_customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    country VARCHAR(50),
    zip_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT '2024-01-01 09:00:00'
);

-- Create indexes that will be used (should NOT trigger T006)
CREATE INDEX idx_products_category ON test_products (category);
CREATE INDEX idx_orders_customer_id ON test_orders (customer_id);
CREATE INDEX idx_orders_order_date ON test_orders (order_date);

-- Create indexes that will NOT be used (should trigger T006)
-- Large text field, unlikely to be used
CREATE INDEX idx_products_unused_description ON test_products (description);
-- Will not be queried in our test
CREATE INDEX idx_products_unused_price ON test_products (price);
-- Text field that won't be queried
CREATE INDEX idx_orders_unused_notes ON test_orders (notes);
-- Won't be queried
CREATE INDEX idx_customers_unused_phone ON test_customers (phone);
-- Won't be queried
CREATE INDEX idx_customers_unused_zip ON test_customers (zip_code);
-- Won't be queried
CREATE INDEX idx_orders_unused_quantity ON test_orders (quantity);

-- Insert test data to make the tables realistic
INSERT INTO test_products (product_name, category, price, sku, description)
VALUES
(
    'Laptop Computer',
    'Electronics',
    999.99,
    'LAP001',
    'High-performance laptop for work and gaming'
),
(
    'Office Chair',
    'Furniture',
    199.50,
    'CHR001',
    'Ergonomic office chair with lumbar support'
),
(
    'Wireless Mouse',
    'Electronics',
    29.99,
    'MOU001',
    'Wireless optical mouse with USB receiver'
),
(
    'Desk Lamp',
    'Furniture',
    49.99,
    'LAM001',
    'LED desk lamp with adjustable brightness'
),
(
    'Keyboard',
    'Electronics',
    79.99,
    'KEY001',
    'Mechanical keyboard with RGB lighting'
),
(
    'Monitor',
    'Electronics',
    299.99,
    'MON001',
    '24-inch 4K monitor with USB-C connectivity'
),
('Bookshelf', 'Furniture', 129.99, 'BSH001', 'Wooden bookshelf with 5 shelves'),
(
    'Webcam',
    'Electronics',
    89.99,
    'CAM001',
    'HD webcam with built-in microphone'
);

-- Insert many more products to increase table and index size significantly
-- This will create larger indexes to trigger T006 thresholds
INSERT INTO test_products (product_name, category, price, sku, description)
SELECT
    'Product ' || i::text,
    CASE (i % 4)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Furniture'
        WHEN 2 THEN 'Home & Garden'
        ELSE 'Sports'
    END,
    (50 + (i % 500))::decimal,
    'SKU' || LPAD(i::text, 6, '0'),
    'Detailed product description for item number ' || i::text || '. ' ||
    'This is a comprehensive description that includes multiple features, specifications, ' ||
    'benefits, and use cases. The product offers excellent value for money and comes with ' ||
    'a warranty. Perfect for customers looking for quality and reliability. ' ||
    'Additional details: manufactured with high-quality materials, tested for durability, ' ||
    'environmentally friendly packaging, customer support included.'
FROM generate_series(1, 100000) AS i;

INSERT INTO test_customers (
    customer_name, email, phone, address, city, country, zip_code
)
VALUES
(
    'John Doe',
    'john.doe@email.com',
    '+1-555-0101',
    '123 Main St',
    'New York',
    'USA',
    '10001'
),
(
    'Jane Smith',
    'jane.smith@email.com',
    '+1-555-0102',
    '456 Oak Ave',
    'Los Angeles',
    'USA',
    '90210'
),
(
    'Bob Johnson',
    'bob.johnson@email.com',
    '+1-555-0103',
    '789 Pine Rd',
    'Chicago',
    'USA',
    '60601'
),
(
    'Alice Brown',
    'alice.brown@email.com',
    '+1-555-0104',
    '321 Elm St',
    'Houston',
    'USA',
    '77001'
),
(
    'Charlie Wilson',
    'charlie.wilson@email.com',
    '+1-555-0105',
    '654 Maple Dr',
    'Phoenix',
    'USA',
    '85001'
);

-- Insert many more customers to increase table and index size
INSERT INTO test_customers (customer_name, email, phone, address, city, country, zip_code)
SELECT
    'Customer ' || i::text,
    'customer' || i::text || '@test.com',
    '+1-555-' || LPAD((i % 10000)::text, 4, '0'),
    (100 + (i % 9900))::text || ' Street ' ||
    CASE (i % 10)
        WHEN 0 THEN 'Ave'
        WHEN 1 THEN 'Blvd'
        WHEN 2 THEN 'Dr'
        WHEN 3 THEN 'St'
        ELSE 'Rd'
    END,
    CASE (i % 20)
        WHEN 0 THEN 'New York'
        WHEN 1 THEN 'Los Angeles'
        WHEN 2 THEN 'Chicago'
        WHEN 3 THEN 'Houston'
        WHEN 4 THEN 'Phoenix'
        WHEN 5 THEN 'Philadelphia'
        WHEN 6 THEN 'San Antonio'
        WHEN 7 THEN 'San Diego'
        WHEN 8 THEN 'Dallas'
        WHEN 9 THEN 'San Jose'
        ELSE 'Austin'
    END,
    'USA',
    LPAD(((i % 90000) + 10000)::text, 5, '0')
FROM generate_series(1, 50000) AS i;

INSERT INTO test_orders (
    customer_id, product_id, quantity, total_amount, status, notes
)
VALUES
(1, 1, 1, 999.99, 'completed', 'Express delivery requested'),
(2, 2, 1, 199.50, 'pending', 'Customer prefers blue color'),
(3, 3, 2, 59.98, 'shipped', 'Gift wrap requested'),
(1, 4, 1, 49.99, 'completed', 'Standard delivery'),
(4, 5, 1, 79.99, 'processing', 'RGB lighting preferred'),
(5, 6, 1, 299.99, 'completed', 'Wall mount included'),
(2, 7, 1, 129.99, 'shipped', 'Assembly service requested'),
(3, 8, 1, 89.99, 'pending', 'Compatible with existing setup');

-- Insert many more orders to increase table and index size significantly
INSERT INTO test_orders (customer_id, product_id, quantity, total_amount, status, notes)
SELECT
    ((i % 50000) + 1),  -- customer_id (referencing the customers we created)
    ((i % 100000) + 1), -- product_id (referencing the products we created)
    (i % 5) + 1,         -- quantity between 1 and 5
    ((50 + (i % 500)) * ((i % 5) + 1))::decimal, -- total_amount
    CASE (i % 5)
        WHEN 0 THEN 'completed'
        WHEN 1 THEN 'pending'
        WHEN 2 THEN 'shipped'
        WHEN 3 THEN 'processing'
        ELSE 'cancelled'
    END,
    'Order note for transaction ' || i::text || '. Customer requested special handling. ' ||
    'Additional shipping instructions provided. Priority processing required for this order. ' ||
    'Quality check completed successfully. Customer satisfaction guaranteed.'
FROM generate_series(1, 200000) AS i;

-- Perform queries that will USE some indexes (making them "used")
-- These queries will increment the idx_scan counter for the used indexes

SELECT 'Performing queries that will use some indexes...' AS status;

-- Query using idx_products_category (this index will be "used")
SELECT COUNT(*) FROM test_products
WHERE category = 'Electronics';
SELECT COUNT(*) FROM test_products
WHERE category = 'Furniture';

-- Query using idx_orders_customer_id (this index will be "used")
SELECT COUNT(*) FROM test_orders
WHERE customer_id = 1;
SELECT COUNT(*) FROM test_orders
WHERE customer_id = 2;
SELECT COUNT(*) FROM test_orders
WHERE customer_id = 3;

-- Query using idx_orders_order_date (this index will be "used")
SELECT COUNT(*) FROM test_orders
WHERE order_date >= '2024-01-01';
SELECT COUNT(*) FROM test_orders
WHERE order_date >= '2024-01-10';

-- Perform additional queries to ensure the "used" indexes have scan counts > 0
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        PERFORM COUNT(*) FROM test_products WHERE category IN ('Electronics', 'Furniture');
        PERFORM COUNT(*) FROM test_orders WHERE customer_id BETWEEN 1 AND 5;
        PERFORM COUNT(*) FROM test_orders WHERE order_date >= '2024-01-01';
    END LOOP;
END$$;

-- Update statistics after the queries
ANALYZE test_products;
ANALYZE test_orders;
ANALYZE test_customers;

-- Give some time for statistics to be updated
SELECT PG_SLEEP(2);

DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION IF NOT EXISTS pglinter;

-- Disable all rules first to isolate T006 testing
SELECT 'Disabling all rules to test T006 specifically...' AS status;
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable T006 specifically
SELECT 'Enabling T006 rule...' AS status;
SELECT pglinter.enable_rule('T006') AS t006_reenabled;

-- Temporarily adjust T006 thresholds for testing using the proper function
-- Default thresholds are 200MB warning, 500MB error - too high for test indexes
-- Set to 1MB warning, 5MB error so our small test indexes will trigger alerts
SELECT 'Adjusting T006 thresholds for testing (1MB warning, 5MB error)...' AS status;
SELECT pglinter.update_rule_levels('T006', 1, 5) AS t006_levels_updated;

-- Verify the threshold change
SELECT 'T006 thresholds after adjustment:' AS info;
SELECT pglinter.get_rule_levels('T006') AS t006_current_levels;

-- Run table check (should show no results since all rules are disabled)
SELECT 'Running table check with all rules disabled (should show no T006 results):' AS test_info;
SELECT pglinter.perform_table_check();

-- Test disabling T006 temporarily
SELECT 'Testing T006 disable/enable cycle:' AS test_info;
SELECT pglinter.disable_rule('T006') AS t006_disabled;
SELECT pglinter.perform_table_check(); -- Should skip T006

-- Restore original T006 thresholds using the proper function
SELECT 'Restoring original T006 thresholds (200MB warning, 500MB error)...' AS status;
SELECT pglinter.update_rule_levels('T006', 200, 500) AS t006_levels_restored;

-- cleanup
DROP TABLE IF EXISTS test_orders CASCADE;
DROP TABLE IF EXISTS test_products CASCADE;
DROP TABLE IF EXISTS test_customers CASCADE;
