# How-To Guides

Practical guides for common pglinter scenarios and use cases.

## Create extension

### download packages

**Debian/Ubuntu Systems:**
```bash
PGVER=17
PGLINTER=0.0.20

wget https://github.com/pmpetit/pglinter/releases/download/${PGVER}/postgresql_pglinter_${PGVER}_${PGLINTER}_amd64.deb
sudo dpkg -i postgresql_pglinter_${PGVER}_${PGLINTER}_amd64.deb

# Fix dependencies if needed
sudo apt-get install -f
```

**RHEL/CentOS/Fedora Systems:**
```bash
PGVER=17
PGLINTER=0.0.20
wget https://github.com/pmpetit/pglinter/releases/download/${PGVER}/postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
sudo rpm -i postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
# or
sudo yum localinstall postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
```

### 💻 Usage

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
