-- Test for T010 rule - Tables with sensitive columns (requires anon extension)
--BEGIN;

\pset pager off

DROP EXTENSION IF EXISTS pglinter CASCADE;

-- First, check if anon extension is available
CREATE EXTENSION IF NOT EXISTS pglinter;

SELECT 'Testing T010 rule - Sensitive columns detection...' AS test_info;

-- Check if anon extension exists
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'anon')
        THEN 'anon extension found - T010 will execute'
        ELSE 'anon extension not found - T010 will be skipped'
    END AS extension_status;

-- Create test schema for sensitive data testing
CREATE SCHEMA test_sensitive_schema;

-- Create tables with potentially sensitive columns
-- These would be detected if anon extension is available
CREATE TABLE test_sensitive_schema.users_with_sensitive_data (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(150),
    first_name VARCHAR(100),    -- Potentially sensitive (first name)
    last_name VARCHAR(100),     -- Potentially sensitive (last name)
    phone_number VARCHAR(20),   -- Potentially sensitive (phone)
    social_security_number VARCHAR(11), -- Potentially sensitive (SSN)
    credit_card_number VARCHAR(19),     -- Potentially sensitive (credit card)
    address VARCHAR(200),       -- Potentially sensitive (address)
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE test_sensitive_schema.customer_data (
    customer_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100),
    contact_person VARCHAR(100), -- Potentially sensitive (person name)
    email_address VARCHAR(150),  -- Potentially sensitive (email)
    phone VARCHAR(15),          -- Potentially sensitive (phone)
    tax_id VARCHAR(20),         -- Potentially sensitive (tax ID)
    bank_account VARCHAR(30),   -- Potentially sensitive (bank account)
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create tables with non-sensitive columns
CREATE TABLE test_sensitive_schema.products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    category VARCHAR(50),
    stock_quantity INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE test_sensitive_schema.categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert test data
INSERT INTO test_sensitive_schema.users_with_sensitive_data
(username, email, first_name, last_name, phone_number, social_security_number, credit_card_number, address)
VALUES
('john_doe', 'john@example.com', 'John', 'Doe', '555-123-4567', '123-45-6789', '4532-1234-5678-9012', '123 Main St, City, State'),
('jane_smith', 'jane@example.com', 'Jane', 'Smith', '555-987-6543', '987-65-4321', '4532-9876-5432-1098', '456 Oak Ave, Town, State');

INSERT INTO test_sensitive_schema.customer_data
(company_name, contact_person, email_address, phone, tax_id, bank_account)
VALUES
('ACME Corp', 'Alice Johnson', 'alice@acme.com', '555-111-2222', '12-3456789', '1234567890'),
('Beta LLC', 'Bob Wilson', 'bob@beta.com', '555-333-4444', '98-7654321', '0987654321');

INSERT INTO test_sensitive_schema.products
(product_name, description, price, category, stock_quantity)
VALUES
('Widget A', 'High-quality widget', 29.99, 'widgets', 100),
('Gadget B', 'Innovative gadget', 49.99, 'gadgets', 50);

INSERT INTO test_sensitive_schema.categories
(category_name, description, is_active)
VALUES
('widgets', 'Various widget products', TRUE),
('gadgets', 'Electronic gadgets', TRUE);

-- Test T010 rule execution
SELECT 'Testing T010 rule execution...' AS test_step;

-- First test: Run with all rules to see T010 behavior
SELECT pglinter.perform_table_check();

-- Test rule management for T010
SELECT 'Testing T010 rule management...' AS test_step;
SELECT pglinter.explain_rule('T010');
SELECT pglinter.is_rule_enabled('T010') AS t010_enabled;

-- Test disabling T010
SELECT 'Testing T010 disable...' AS test_step;
SELECT pglinter.disable_rule('T010') AS t010_disabled;
SELECT pglinter.perform_table_check(); -- Should skip T010

-- Re-enable T010
SELECT 'Testing T010 re-enable...' AS test_step;
SELECT pglinter.enable_rule('T010') AS t010_reenabled;
SELECT pglinter.perform_table_check(); -- Should include T010 again

-- Test with only T010 enabled
SELECT 'Testing T010 in isolation...' AS test_step;
SELECT pglinter.disable_all_rules() AS all_disabled;
SELECT pglinter.enable_rule('T010') AS t010_only_enabled;
SELECT pglinter.perform_table_check(); -- Should only run T010

-- Final extension status check
SELECT 'Final check - Extension availability affects T010 execution:' AS final_info;
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'anon')
        THEN 'T010 executed with anon extension'
        ELSE 'T010 skipped - anon extension not available'
    END AS execution_result;

--ROLLBACK;
