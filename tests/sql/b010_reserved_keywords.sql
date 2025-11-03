-- Simple example to demonstrate reserved keywords in object names detection (B010 rule)
-- This script creates database objects using reserved keywords as names
-- and shows how the B010 rule detects these naming violations.
CREATE EXTENSION pglinter;


\pset pager off

-- Create test schemas for object creation
CREATE SCHEMA test_keywords_schema;
CREATE SCHEMA test_naming_schema;

-- Create tables using reserved keywords (should trigger B010)
CREATE TABLE test_keywords_schema."SELECT" (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

CREATE TABLE test_keywords_schema."FROM" (
    id SERIAL PRIMARY KEY,
    source_name VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

CREATE TABLE test_naming_schema."WHERE" (
    id SERIAL PRIMARY KEY,
    condition_text TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

CREATE TABLE test_naming_schema."ORDER" (
    order_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100),
    total_amount DECIMAL(10, 2),
    order_date DATE DEFAULT '2024-01-15',
    created_at TIMESTAMP DEFAULT '2024-01-15 11:00:00'
);

-- Create tables with columns using reserved keywords (should trigger B010)
CREATE TABLE test_keywords_schema.products_with_bad_columns (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    "GROUP" VARCHAR(50),  -- Reserved keyword as column name
    "HAVING" TEXT,        -- Reserved keyword as column name
    "UNION" INTEGER,      -- Reserved keyword as column name
    price DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

CREATE TABLE test_naming_schema.users_with_bad_columns (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    "JOIN" VARCHAR(100),     -- Reserved keyword as column name
    "LIMIT" INTEGER,         -- Reserved keyword as column name
    "OFFSET" INTEGER,        -- Reserved keyword as column name
    email VARCHAR(150),
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

-- Create views using reserved keywords (should trigger B010)
CREATE VIEW test_keywords_schema."DISTINCT" AS
SELECT product_id, product_name, price
FROM test_keywords_schema.products_with_bad_columns
WHERE price > 10.00;

CREATE VIEW test_naming_schema."INNER" AS
SELECT user_id, username, email
FROM test_naming_schema.users_with_bad_columns
WHERE user_id > 0;

-- Create sequences using reserved keywords (should trigger B010)
CREATE SEQUENCE test_keywords_schema."NULL";
CREATE SEQUENCE test_naming_schema."TRUE";
CREATE SEQUENCE test_keywords_schema."FALSE";

-- Create indexes using reserved keywords (should trigger B010)
CREATE INDEX "PRIMARY" ON test_keywords_schema.products_with_bad_columns (product_name);
CREATE INDEX "UNIQUE" ON test_naming_schema.users_with_bad_columns (username);
CREATE INDEX "FOREIGN" ON test_keywords_schema."FROM" (source_name);

-- Create functions using reserved keywords (should trigger B010)
CREATE FUNCTION test_keywords_schema."AND"(a INTEGER, b INTEGER)
RETURNS INTEGER AS $$
BEGIN
    RETURN a + b;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION test_naming_schema."OR"(x TEXT, y TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN CONCAT(x, ' OR ', y);
END;
$$ LANGUAGE plpgsql;

-- Create user-defined types using reserved keywords (should trigger B010)
CREATE TYPE test_keywords_schema."CASE" AS ENUM ('option1', 'option2', 'option3');
CREATE TYPE test_naming_schema."WHEN" AS (
    condition TEXT,
    result INTEGER
);

-- Create triggers using reserved keywords (should trigger B010)
CREATE OR REPLACE FUNCTION test_keywords_schema."THEN"()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "ELSE"
    BEFORE UPDATE ON test_keywords_schema.products_with_bad_columns
    FOR EACH ROW EXECUTE FUNCTION test_keywords_schema."THEN"();

CREATE OR REPLACE FUNCTION test_naming_schema."END"()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "BINARY"
    BEFORE UPDATE ON test_naming_schema.users_with_bad_columns
    FOR EACH ROW EXECUTE FUNCTION test_naming_schema."END"();

-- Create tables and objects with GOOD names (should NOT trigger B010)
CREATE TABLE test_keywords_schema.good_products (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

CREATE TABLE test_naming_schema.good_users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(150),
    full_name VARCHAR(200),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT '2024-01-01 10:00:00'
);

CREATE VIEW test_keywords_schema.active_products AS
SELECT id, product_name, price
FROM test_keywords_schema.good_products
WHERE price > 0;

CREATE SEQUENCE test_naming_schema.user_id_seq;
CREATE INDEX idx_product_name ON test_keywords_schema.good_products (product_name);
CREATE INDEX idx_username ON test_naming_schema.good_users (username);

-- Insert test data
INSERT INTO test_keywords_schema."SELECT" (data) VALUES
('Test data 1'),
('Test data 2'),
('Test data 3');

INSERT INTO test_keywords_schema."FROM" (source_name, description) VALUES
('Source A', 'Primary data source'),
('Source B', 'Secondary data source'),
('Source C', 'Backup data source');

INSERT INTO test_naming_schema."WHERE" (condition_text, is_active) VALUES
('status = active', TRUE),
('price > 100', TRUE),
('category IS NOT NULL', FALSE);

INSERT INTO test_naming_schema."ORDER" (customer_name, total_amount, order_date) VALUES
('John Doe', 150.99, '2024-01-10'),
('Jane Smith', 275.50, '2024-01-11'),
('Bob Johnson', 89.99, '2024-01-12');

INSERT INTO test_keywords_schema.products_with_bad_columns
(product_name, "GROUP", "HAVING", "UNION", price) VALUES
('Product A', 'electronics', 'High quality', 1, 99.99),
('Product B', 'books', 'Educational', 2, 29.99),
('Product C', 'clothing', 'Fashion', 3, 49.99);

INSERT INTO test_naming_schema.users_with_bad_columns
(username, "JOIN", "LIMIT", "OFFSET", email) VALUES
('user1', 'member', 100, 0, 'user1@test.com'),
('user2', 'admin', 200, 10, 'user2@test.com'),
('user3', 'guest', 50, 5, 'user3@test.com');

INSERT INTO test_keywords_schema.good_products
(product_name, description, price, category) VALUES
('Good Product 1', 'A well-named product', 79.99, 'electronics'),
('Good Product 2', 'Another well-named product', 129.99, 'books');

INSERT INTO test_naming_schema.good_users
(username, email, full_name, status) VALUES
('gooduser1', 'good1@test.com', 'Good User One', 'active'),
('gooduser2', 'good2@test.com', 'Good User Two', 'active');

-- Update statistics for better query planning
ANALYZE test_keywords_schema."SELECT";
ANALYZE test_keywords_schema."FROM";
ANALYZE test_naming_schema."WHERE";
ANALYZE test_naming_schema."ORDER";
ANALYZE test_keywords_schema.products_with_bad_columns;
ANALYZE test_naming_schema.users_with_bad_columns;
ANALYZE test_keywords_schema.good_products;
ANALYZE test_naming_schema.good_users;



-- Disable all rules first to isolate B010 testing
SELECT 'Disabling all rules to test B010 specifically...' AS status;
SELECT pglinter.disable_all_rules() AS all_rules_disabled;
SELECT pglinter.enable_rule('B010') AS B010_enabled;

-- Run table check (should detect objects with reserved keyword names)
SELECT 'Running table check with only B010 enabled:' AS test_info;
SELECT pglinter.perform_base_check();

-- Test disabling B010 temporarily
SELECT 'Testing B010 disable/enable cycle:' AS test_info;
SELECT pglinter.disable_rule('B010') AS B010_disabled;
SELECT pglinter.perform_base_check(); -- Should skip B010

-- Re-enable B010 and test again
SELECT pglinter.enable_rule('B010') AS B010_re_enabled;
SELECT pglinter.perform_base_check(); -- Should include B010 again

-- ROLLBACK;

DROP SCHEMA test_keywords_schema CASCADE;
DROP SCHEMA test_naming_schema CASCADE;

DROP EXTENSION pglinter CASCADE;
