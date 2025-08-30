-- Test for T008 rule - Tables with foreign key type mismatches
BEGIN;

DROP EXTENSION IF EXISTS pg_linter CASCADE;

-- Create parent tables with different types
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL
);

CREATE TABLE categories (
    id SMALLINT PRIMARY KEY,
    name TEXT NOT NULL
);

-- Create child tables with type mismatches
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER, -- Type mismatch: should be BIGINT to match users.id
    category_id INTEGER, -- Type mismatch: should be SMALLINT to match categories.id
    total NUMERIC
);

-- Add foreign key constraints that have type mismatches
ALTER TABLE orders
ADD CONSTRAINT fk_orders_user
FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE orders
ADD CONSTRAINT fk_orders_category
FOREIGN KEY (category_id) REFERENCES categories(id);

-- Create a table with correct foreign key types
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id BIGINT, -- Correct type matching users.id
    category_id SMALLINT, -- Correct type matching categories.id
    rating INTEGER
);

-- Add foreign keys with correct types
ALTER TABLE reviews
ADD CONSTRAINT fk_reviews_user
FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE reviews
ADD CONSTRAINT fk_reviews_category
FOREIGN KEY (category_id) REFERENCES categories(id);

-- Insert some test data
INSERT INTO users (username) VALUES ('user1'), ('user2');
INSERT INTO categories (id, name) VALUES (1, 'Electronics'), (2, 'Books');
INSERT INTO orders (user_id, category_id, total) VALUES (1, 1, 99.99);
INSERT INTO reviews (user_id, category_id, rating) VALUES (1, 1, 5);

CREATE EXTENSION IF NOT EXISTS pg_linter;

-- Test the T008 rule
SELECT 'Testing T008 rule - Foreign key type mismatches...' as test_info;

-- Run table check to detect type mismatches
SELECT pg_linter.perform_table_check();

-- Test rule management
SELECT pg_linter.explain_rule('T008');
SELECT pg_linter.is_rule_enabled('T008') AS t008_enabled;

-- Test disabling T008
SELECT pg_linter.disable_rule('T008') AS t008_disabled;
SELECT pg_linter.perform_table_check(); -- Should skip T008

-- Re-enable T008
SELECT pg_linter.enable_rule('T008') AS t008_reenabled;
SELECT pg_linter.perform_table_check(); -- Should include T008 again

-- Clean up
DROP TABLE reviews CASCADE;
DROP TABLE orders CASCADE;
DROP TABLE categories CASCADE;
DROP TABLE users CASCADE;

ROLLBACK;
