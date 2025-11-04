-- Test for B007 rule - Tables with foreign keys outside their schema (Base level)
-- This test creates tables with foreign keys crossing schema boundaries
-- and verifies that B007 correctly counts the percentage at database level
CREATE EXTENSION pglinter;

\pset pager off

-- Create test schemas
CREATE SCHEMA public_schema;
CREATE SCHEMA sales_schema;
CREATE SCHEMA inventory_schema;
CREATE SCHEMA audit_schema;
CREATE SCHEMA clean_schema;

-- Create referenced tables in public_schema (these will be referenced by other schemas)
CREATE TABLE public_schema.customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE public_schema.products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(50),
    stock_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE public_schema.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create tables with CROSS-SCHEMA foreign keys (should be counted by B007)
-- These tables have FKs pointing outside their schema

-- Sales schema table with FK to public_schema (CROSS-SCHEMA - should be counted)
CREATE TABLE sales_schema.orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES public_schema.customers(customer_id), -- Cross-schema FK
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Another sales schema table with FK to public_schema (CROSS-SCHEMA - should be counted)
CREATE TABLE sales_schema.order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES sales_schema.orders(order_id), -- Same schema - OK
    product_id INTEGER NOT NULL REFERENCES public_schema.products(product_id), -- Cross-schema FK
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Inventory schema table with FK to public_schema (CROSS-SCHEMA - should be counted)
CREATE TABLE inventory_schema.stock_movements (
    movement_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES public_schema.products(product_id), -- Cross-schema FK
    movement_type VARCHAR(20) NOT NULL, -- 'IN', 'OUT', 'ADJUSTMENT'
    quantity INTEGER NOT NULL,
    movement_date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Audit schema table with FK to public_schema (CROSS-SCHEMA - should be counted)
CREATE TABLE audit_schema.user_actions (
    action_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES public_schema.users(user_id), -- Cross-schema FK
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id INTEGER,
    action_timestamp TIMESTAMP DEFAULT NOW(),
    details JSONB
);

-- Create tables WITHOUT cross-schema foreign keys (should NOT be counted by B007)
-- These tables either have no FKs or only have FKs within their own schema

-- Clean schema with internal FKs only (should NOT be counted)
CREATE TABLE clean_schema.departments (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE clean_schema.employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(150) UNIQUE,
    department_id INTEGER REFERENCES clean_schema.departments(department_id), -- Same schema FK - OK
    hire_date DATE DEFAULT CURRENT_DATE,
    salary DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Another table with no foreign keys (should NOT be counted)
CREATE TABLE clean_schema.company_settings (
    setting_id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    description TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Public schema table with internal FK only (should NOT be counted)
CREATE TABLE public_schema.customer_addresses (
    address_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES public_schema.customers(customer_id), -- Same schema FK - OK
    address_type VARCHAR(20) DEFAULT 'home', -- 'home', 'work', 'billing'
    street_address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(50) DEFAULT 'USA',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert test data to make the test more realistic
INSERT INTO public_schema.customers (customer_name, email, phone) VALUES
('John Doe', 'john@example.com', '555-0101'),
('Jane Smith', 'jane@example.com', '555-0102'),
('Bob Johnson', 'bob@example.com', '555-0103');

INSERT INTO public_schema.products (product_name, price, category, stock_quantity) VALUES
('Widget A', 29.99, 'widgets', 100),
('Gadget B', 49.99, 'gadgets', 50),
('Tool C', 79.99, 'tools', 25);

INSERT INTO public_schema.users (username, email) VALUES
('admin', 'admin@company.com'),
('user1', 'user1@company.com'),
('user2', 'user2@company.com');

INSERT INTO sales_schema.orders (customer_id, total_amount, status) VALUES
(1, 159.97, 'completed'),
(2, 49.99, 'pending'),
(3, 109.98, 'shipped');

INSERT INTO sales_schema.order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 2, 29.99),
(1, 3, 1, 79.99),
(2, 2, 1, 49.99),
(3, 1, 1, 29.99);

INSERT INTO clean_schema.departments (department_name, description) VALUES
('Engineering', 'Software development team'),
('Sales', 'Sales and marketing team'),
('HR', 'Human resources');

INSERT INTO clean_schema.employees (first_name, last_name, email, department_id, salary) VALUES
('Alice', 'Engineer', 'alice@company.com', 1, 85000.00),
('Bob', 'Salesman', 'bob@company.com', 2, 65000.00),
('Carol', 'HR Manager', 'carol@company.com', 3, 75000.00);

-- Create the pglinter extension


-- Test B007 rule execution
SELECT 'Testing B007 rule - Tables with foreign keys outside schema...' AS test_info;

-- Test the B007 rule with base check
SELECT 'Running base check to test B007 rule:' AS test_step;
SELECT pglinter.check();

-- Test rule management for B007
SELECT 'Testing B007 rule management...' AS test_step;
SELECT pglinter.explain_rule('B007');
SELECT pglinter.is_rule_enabled('B007') AS B007_enabled;

-- Test disabling B007
SELECT 'Testing B007 disable...' AS test_step;
SELECT pglinter.disable_rule('B007') AS B007_disabled;
SELECT pglinter.check(); -- Should skip B007

-- Re-enable B007
SELECT 'Testing B007 re-enable...' AS test_step;
SELECT pglinter.enable_rule('B007') AS B007_reenabled;
SELECT pglinter.check(); -- Should include B007 again

-- Test with only B007 enabled
SELECT 'Testing B007 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('B007') AS B007_only_enabled;
SELECT pglinter.check(); -- Should only run B007

-- Show rule status
SELECT 'Current B007 rule status:' AS status_info;
SELECT * FROM pglinter.rules WHERE code = 'B007';

-- Test threshold configuration
SELECT 'Testing B007 threshold configuration...' AS test_step;
SELECT pglinter.get_rule_levels('B007') AS current_B007_levels;

-- Make B007 more strict temporarily
SELECT pglinter.update_rule_levels('B007', 10, 30) AS B007_strict_update;
SELECT 'B007 with stricter thresholds (should trigger more easily):' AS strict_test;
SELECT pglinter.check();

-- Test if file exists and show checksum
SELECT pglinter.check('/tmp/pglinter_B007_results.sarif');
\! md5sum /tmp/pglinter_B007_results.sarif

-- Reset to original levels
SELECT pglinter.update_rule_levels('B007', 20, 80) AS B007_reset_levels;

DROP SCHEMA public_schema CASCADE;
DROP SCHEMA sales_schema CASCADE;
DROP SCHEMA inventory_schema CASCADE;
DROP SCHEMA audit_schema CASCADE;
DROP SCHEMA clean_schema CASCADE;

DROP EXTENSION pglinter CASCADE;
