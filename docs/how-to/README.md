# How-To Guides

Practical guides for common pglinter scenarios and use cases.

## 💻 Usage

After installation, enable the extension in your PostgreSQL database:

```sql
-- Connect to your database
\c your_database

-- Create the extension
CREATE EXTENSION pglinter;

-- Get all violations
SELECT * FROM pglinter.get_violations();

-- Filter violations for a specific rule
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B001';  -- Tables without primary keys
SELECT * FROM pglinter.get_violations() WHERE rule_code = 'B002';  -- Redundant indexes
```

### 📋 Available Rules

- **B00**: Base database rules (primary keys, indexes, schemas, etc.)
- **C00**: Cluster security rules
- **S00**: Schema rules
