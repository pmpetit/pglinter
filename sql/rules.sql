CREATE TABLE IF NOT EXISTS dblinter.rules (
    id INT PRIMARY KEY,
    name TEXT,
    code TEXT,
    enable BOOL DEFAULT TRUE,
    query TEXT,
    warning_level INT,
    error_level INT,
    scope TEXT
);

-- Clear existing data and insert comprehensive rules
DELETE FROM dblinter.rules;

INSERT INTO dblinter.rules (id,name,code,query,warning_level,error_level,scope) VALUES 
-- Base Database Rules (B series)
(1, 'HowManyTableWithoutPrimaryKey', 'B001', '', 10, 70, 'BASE'),
(2, 'HowManyRedudantIndex', 'B002', '', 5, 50, 'BASE'),
(3, 'HowManyTableWithoutIndexOnFk', 'B003', '', 10, 70, 'BASE'),
(4, 'HowManyUnusedIndex', 'B004', '', 5, 50, 'BASE'),
(5, 'UnsecuredPublicSchema', 'B005', '', 1, 1, 'BASE'),
(6, 'HowManyTablesWithUppercase', 'B006', '', 10, 70, 'BASE'),

-- Cluster Rules (C series)
(10, 'MaxConnectionsByWorkMemIsNotLargerThanMemory', 'C001', '', 1, 1, 'CLUSTER'),
(11, 'PgHbaEntriesWithMethodTrustOrPasswordShouldNotExists', 'C002', '', 1, 1, 'CLUSTER'),

-- Table Rules (T series)
(20, 'TableWithoutPrimaryKey', 'T001', '', 1, 1, 'TABLE'),
(21, 'TableWithoutIndex', 'T002', '', 1, 1, 'TABLE'),
(22, 'TableWithTooManyIndex', 'T003', '', 10, 20, 'TABLE'),
(23, 'TableWithoutIndexOnFK', 'T004', '', 1, 1, 'TABLE'),
(24, 'TableWithUnusedIndex', 'T005', '', 1, 1, 'TABLE'),
(25, 'TableWithRedundantIndex', 'T006', '', 1, 1, 'TABLE'),
(26, 'TableWithMissingFK', 'T007', '', 1, 1, 'TABLE'),
(27, 'TableWithUpperCaseName', 'T008', '', 1, 1, 'TABLE'),
(28, 'TableWithUpperCaseColumn', 'T009', '', 1, 1, 'TABLE'),
(29, 'TableWithTooManyColumn', 'T010', '', 10, 20, 'TABLE'),
(30, 'TableWithOnlyNullableColumn', 'T011', '', 1, 1, 'TABLE'),
(31, 'TableWithoutComment', 'T012', '', 50, 80, 'TABLE'),

-- Schema Rules (S series)
(40, 'SchemaWithoutPrivileges', 'S001', '', 1, 1, 'SCHEMA'),
(41, 'SchemaWithPublicPrivileges', 'S002', '', 1, 1, 'SCHEMA');


