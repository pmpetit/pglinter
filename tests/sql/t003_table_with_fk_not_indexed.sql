-- Example to demonstrate missing index on foreign key and T003 rule detection
CREATE EXTENSION pglinter;

\pset pager off

-- Create tables: parent with PK, child with FK but no index on FK
CREATE TABLE parent (
    id INTEGER PRIMARY KEY,
    name TEXT
);

CREATE TABLE child (
    child_id INTEGER PRIMARY KEY,
    parent_id INTEGER NOT NULL,
    value TEXT,
    CONSTRAINT fk_parent FOREIGN KEY (parent_id) REFERENCES parent(id)
);

-- No index on child.parent_id (foreign key column)

-- Insert some test data
INSERT INTO parent (id, name) VALUES (1, 'A'), (2, 'B');
INSERT INTO child (child_id, parent_id, value) VALUES (10, 1, 'foo'), (11, 2, 'bar');

-- Update table statistics
ANALYZE parent;
ANALYZE child;



-- Disable all rules first to isolate T004 testing
SELECT pglinter.disable_all_rules() AS all_rules_disabled;

-- Enable T003 specifically
SELECT pglinter.enable_rule('T003') AS t003_enabled;

-- Run table check to detect FKs without index
SELECT pglinter.perform_table_check(); -- Should include T004 results

-- Now let's fix the missing index issue
CREATE INDEX idx_child_parent_id ON child(parent_id);

-- Update statistics after schema changes
ANALYZE child;

-- Run T004 check again (should show no issues now)
SELECT pglinter.perform_table_check();


DROP TABLE child CASCADE;
DROP TABLE parent CASCADE;

DROP EXTENSION pglinter CASCADE;
