# How-To Guides

Practical guides for common pglinter scenarios and use cases.

## 💻 Usage

After installation, enable the extension in your PostgreSQL database:

```sql
-- Connect to your database
\c your_database

-- Create the extension
CREATE EXTENSION pglinter;

-- Run a basic check
SELECT pglinter.check();

-- Check specific rules
SELECT pglinter.check_rule('B001');  -- Tables without primary keys
SELECT pglinter.check_rule('B002');  -- Redundant indexes
```

### 📋 Available Rules

- **B00**: Base database rules (primary keys, indexes, schemas, etc.)
- **C00**: Cluster security rules
- **S00**: Schema rules
