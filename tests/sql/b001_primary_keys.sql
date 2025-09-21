-- Simple example to demonstrate database-wide primary key analysis and B001 rule detection
-- This script creates multiple tables with and without primary keys to test the B001 percentage-based rule

BEGIN;

-- Create tables WITHOUT primary keys to trigger B001 rule (need enough to exceed 20% threshold)
-- These tables will contribute to the "tables without primary key" count

CREATE TABLE orders_no_pk (
    order_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    quantity INTEGER DEFAULT 1,
    total_amount DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE customers_no_pk (
    customer_id INTEGER NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    state VARCHAR(20),
    zip_code VARCHAR(10)
);

CREATE TABLE products_no_pk (
    product_id INTEGER NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    description TEXT,
    category_id INTEGER,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE reviews_no_pk (
    review_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    review_date DATE DEFAULT CURRENT_DATE,
    helpful_votes INTEGER DEFAULT 0
);

CREATE TABLE inventory_no_pk (
    inventory_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    warehouse_location VARCHAR(50),
    quantity_on_hand INTEGER DEFAULT 0,
    quantity_reserved INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE shipments_no_pk (
    shipment_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    tracking_number VARCHAR(100),
    carrier VARCHAR(50),
    shipped_date DATE,
    estimated_delivery DATE,
    actual_delivery DATE,
    shipment_status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE payments_no_pk (
    payment_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transaction_reference VARCHAR(100),
    payment_status VARCHAR(20) DEFAULT 'pending'
);

-- Create some tables WITH primary keys (these will NOT contribute to the problem)
CREATE TABLE categories_with_pk (
    id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    description TEXT,
    parent_category_id INTEGER,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE users_with_pk (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE TABLE settings_with_pk (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- Insert some test data to make tables more realistic
INSERT INTO orders_no_pk (order_id, customer_id, product_id, quantity, total_amount, status) VALUES
(1001, 1, 101, 2, 59.98, 'completed'),
(1002, 2, 102, 1, 29.99, 'pending'),
(1003, 1, 103, 3, 89.97, 'shipped');

INSERT INTO customers_no_pk (customer_id, first_name, last_name, email, phone) VALUES
(1, 'John', 'Doe', 'john.doe@example.com', '555-0101'),
(2, 'Jane', 'Smith', 'jane.smith@example.com', '555-0102'),
(3, 'Bob', 'Johnson', 'bob.johnson@example.com', '555-0103');

INSERT INTO products_no_pk (product_id, product_name, description, category_id, price, stock_quantity) VALUES
(101, 'Laptop Computer', 'High-performance laptop', 1, 899.99, 50),
(102, 'Wireless Mouse', 'Ergonomic wireless mouse', 2, 24.99, 100),
(103, 'Keyboard', 'Mechanical keyboard', 2, 79.99, 75);

INSERT INTO categories_with_pk (category_name, description) VALUES
('Electronics', 'Electronic devices and accessories'),
('Computers', 'Computer hardware and peripherals'),
('Office Supplies', 'General office equipment');

INSERT INTO users_with_pk (username, email, password_hash) VALUES
('admin', 'admin@example.com', 'hashed_password_1'),
('user1', 'user1@example.com', 'hashed_password_2'),
('user2', 'user2@example.com', 'hashed_password_3');

-- Update table statistics
ANALYZE orders_no_pk;
ANALYZE customers_no_pk;
ANALYZE products_no_pk;
ANALYZE reviews_no_pk;
ANALYZE inventory_no_pk;
ANALYZE shipments_no_pk;
ANALYZE payments_no_pk;
ANALYZE categories_with_pk;
ANALYZE users_with_pk;
ANALYZE settings_with_pk;

-- Create the extension and test B001 rule
DROP EXTENSION IF EXISTS pglinter CASCADE;
CREATE EXTENSION IF NOT EXISTS pglinter;

SELECT 'Testing B001 rule - Database-wide primary key percentage analysis...' AS test_info;

-- First, disable all rules to isolate B001 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable only B001 for focused testing
SELECT pglinter.enable_rule('B001') AS b001_enabled;

-- Verify B001 is enabled
SELECT pglinter.is_rule_enabled('B001') AS b001_status;

-- Run base check to detect database-wide primary key percentage issues
SELECT 'Running base check to detect B001 violations...' AS status;
SELECT pglinter.perform_base_check();

-- Test rule management for B001
SELECT 'Testing B001 rule management...' AS test_section;

-- Disable B001 temporarily
SELECT pglinter.disable_rule('B001') AS b001_disabled;
SELECT pglinter.is_rule_enabled('B001') AS b001_status_after_disable;

-- Run base check again (should skip B001)
SELECT 'Running base check with B001 disabled (should find no B001 violations)...' AS status;
SELECT pglinter.perform_base_check();

-- Re-enable B001
SELECT pglinter.enable_rule('B001') AS b001_reenabled;
SELECT pglinter.is_rule_enabled('B001') AS b001_status_after_enable;

-- Run base check again (should detect B001 violations)
SELECT 'Running base check with B001 re-enabled...' AS status;
SELECT pglinter.perform_base_check();

-- Now let's fix some of the issues by adding primary keys to reduce the percentage
SELECT 'Adding primary keys to some tables to improve the percentage...' AS improvement_info;

-- Add primary keys to reduce the percentage below the 20% threshold
ALTER TABLE orders_no_pk ADD CONSTRAINT pk_orders PRIMARY KEY (order_id);
ALTER TABLE customers_no_pk ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);
ALTER TABLE products_no_pk ADD CONSTRAINT pk_products PRIMARY KEY (product_id);
ALTER TABLE reviews_no_pk ADD CONSTRAINT pk_reviews PRIMARY KEY (review_id);
ALTER TABLE inventory_no_pk ADD CONSTRAINT pk_inventory PRIMARY KEY (inventory_id);

-- Keep 2 tables without primary keys to maintain some violations but below threshold
-- shipments_no_pk and payments_no_pk will remain without primary keys

-- Run B001 check again (should show reduced violations or no violations)
SELECT 'Running B001 check after adding primary keys (should show improved percentage):' AS test_info;
SELECT pglinter.perform_base_check();
SELECT pglinter.perform_base_check('/tmp/pglinter_b001_results.sarif');
\! md5sum /tmp/pglinter_b001_results.sarif

ROLLBACK;
