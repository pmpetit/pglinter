# pglinter - PostgreSQL Extension.

This is a conversion of the original Python [dblinter](https://github.com/decathlon/dblinter) to a PostgreSQL extension written in Rust using pgrx.

## Overview

In recent years, DBAs were more involved with the database engine itself—creating instances, configuring backups, and monitoring systems—while also overseeing developers' activities. Today, in the DBRE world where databases are cloud-managed, developers and operations teams often work independently, without a dedicated DBA.
So databases objects lives their own life, created by persons that do their best. It can be usefull to be able to detect some wrong design creation (for example foreign keys created accross differents schemas...). That's what pglinter was created for.

pglinter is a PostgreSQL linter that analyzes your database for potential issues, performance problems, and best practice violations. This Rust implementation provides:

- **Better Performance**: Native Rust performance vs Python
- **Deep Integration**: Runs directly inside PostgreSQL using pgrx
- **SARIF Output**: Industry-standard Static Analysis Results Interchange Format
- **Extensible Rules**: Easy to add new rules using Rust traits

## PostgreSQL Compatibility

This extension is built with **pgrx 0.16.1** and supports:

- PostgreSQL 13
- PostgreSQL 14
- PostgreSQL 15
- PostgreSQL 16
- PostgreSQL 17
- PostgreSQL 18beta2 ✨ (latest with pgrx 0.16.1)

## Architecture

### Rule Categories

- **B (Base/Database)**: Database-wide checks including tables, indexes, constraints, and general database analysis
- **C (Cluster)**: PostgreSQL cluster configuration checks
- **S (Schema)**: Schema-level checks

### Key Components

1. **Rule Engine** (`rule_engine.rs`): Core engine that executes rules
2. **Rule Trait**: Common interface for all rules
3. **SARIF Generator**: Creates standardized output format
4. **Configuration**: Database-stored rule configurations

## Installation

### Requirements

- Rust 1.88.0+ (required for pgrx 0.16.1)
- PostgreSQL 13-18 development packages
- cargo-pgrx 0.16.1

### Install from package

**Debian/Ubuntu Systems:**

```bash
PGVER=17
PGLINTER=1.0.0

wget https://github.com/pmpetit/pglinter/releases/download/${PGVER}/postgresql_pglinter_${PGVER}_${PGLINTER}_amd64.deb
sudo dpkg -i postgresql_pglinter_${PGVER}_${PGLINTER}_amd64.deb
```

**RHEL/CentOS/Fedora Systems:**

```bash
PGVER=17
PGLINTER=1.0.0
wget https://github.com/pmpetit/pglinter/releases/download/${PGVER}/postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
sudo rpm -i postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
# or
sudo yum localinstall postgresql_pglinter_${PGVER}-${PGLINTER}-1.x86_64.rpm
```

### Build and Install

```bash
# Install cargo-pgrx if not already installed
cargo install --locked cargo-pgrx

# Initialize pgrx (one time setup)
cargo pgrx init

# Build the extension for your PostgreSQL version
cargo pgrx package

# Install using the Makefile (handles both system and pgrx-managed PostgreSQL)
sudo make install

# Or install manually for a specific PostgreSQL version
sudo PGVER=pg16 make install

# Load in your database
psql -d your_database -c "CREATE EXTENSION pglinter;"
```

### kubernetes : install from oci image

on kubernetes, prerequisite are

- pg18
- k8s >= 1.33
- K8s feature ImageVolume enable

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-pglinter
spec:
  instances: 1

  storage:
    size: 1Gi

  postgresql:
    extensions:
      - name: pglinter
        image:
          reference: ghcr.io/pmpetit/pglinter:1.0.0-18-bookworm

```

#### Enable Extension in Database

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: cluster-pglinter-app
spec:
  name: app
  owner: app
  cluster:
    name: postgres-with-pglinter
  extensions:
  - name: pglinter
```

After the cluster is running, connect and enable the extension:

```sql
-- Connect to your database
\c app

-- Create the extension
CREATE EXTENSION pglinter;

-- Verify installation
SELECT pglinter.check();
```

#### Declarative Extension Management

You can also use CloudNative-PG's declarative database management:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: cluster-pglinter-app
spec:
  name: app
  owner: app
  cluster:
    name: cluster-pglinter
  extensions:
  - name: pglinter
```

then

```log
postgres=# \dx
                          List of installed extensions
  Name   | Version | Default version |   Schema   |         Description
---------+---------+-----------------+------------+------------------------------
 plpgsql | 1.0     | 1.0             | pg_catalog | PL/pgSQL procedural language
(1 row)

postgres=# \l
                                                List of databases
   Name    |  Owner   | Encoding | Locale Provider | Collate | Ctype | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+---------+-------+--------+-----------+-----------------------
 app       | app      | UTF8     | libc            | C       | C     |        |           |
 postgres  | postgres | UTF8     | libc            | C       | C     |        |           |
 template0 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
(4 rows)

postgres=# \c app
You are now connected to database "app" as user "postgres".
app=# \dx
                                           List of installed extensions
   Name   | Version | Default version |   Schema   |                         Description
----------+---------+-----------------+------------+--------------------------------------------------------------
 pglinter | 1.0.0   | 1.0.0           | public     | pglinter: PostgreSQL Database Linting and Analysis Extension
 plpgsql  | 1.0     | 1.0             | pg_catalog | PL/pgSQL procedural language
(2 rows)

app=#

```

pglinter extension is installed.

## Usage

The extension provides comprehensive database analysis functions:

```sql
-- Run all enabled rules (output to client)
SELECT pglinter.check();

-- Run a specific rule only
SELECT pglinter.check_rule('B001');              -- Check tables without primary keys
SELECT pglinter.check_rule('b002');              -- Case-insensitive rule codes

-- Generate SARIF reports to file
SELECT pglinter.check('/path/to/results.sarif');
SELECT pglinter.check_rule('B001', '/path/to/b001_results.sarif');

-- Rule management
SELECT pglinter.show_rules();                    -- Show all rules and status
SELECT pglinter.explain_rule('B001');            -- Get rule details and fixes
SELECT pglinter.enable_rule('B001');             -- Enable specific rule
SELECT pglinter.disable_rule('B001');            -- Disable specific rule
SELECT pglinter.is_rule_enabled('B001');         -- Check rule status
SELECT pglinter.enable_all_rules();              -- Enable all rules
SELECT pglinter.disable_all_rules();             -- Disable all rules

-- Rule configuration
SELECT pglinter.update_rule_levels('B001', 30, 70);  -- Set warning/error thresholds
SELECT pglinter.get_rule_levels('B001');             -- Get current thresholds

-- YAML import/export
SELECT pglinter.export_rules_to_yaml();              -- Export rules to YAML
SELECT pglinter.import_rules_from_yaml('yaml...');   -- Import rules from YAML
```

## Implemented Rules

### Base Rules (B-series)
- **B001**: Tables without primary keys
- **B002**: Redundant indexes
- **B003**: Tables without indexes on foreign keys
- **B004**: Unused indexes
- **B005**: Tables with uppercase names/columns
- **B006**: Tables not selected (unused tables)
- **B007**: Foreign keys outside schema boundaries
- **B008**: Foreign key type mismatches
- **B009**: Tables sharing trigger functions
- **B010**: Reserved keywords in object names
- **B011**: Multiple table owners in same schema

### Cluster Rules (C-series)

- **C002**: Insecure pg_hba.conf entries
- **C003**: MD5 password encryption (deprecated/insecure)

### Schema Rules (S-series)

- **S001**: Schemas without default role grants
- **S002**: Schemas with environment prefixes/suffixes
- **S003**: Unsecured public schema
- **S004**: Schema owned by internal/system roles
- **S005**: Multiple table owners in same schema

## Rule Implementation

Adding a new rule is straightforward. For a comprehensive step-by-step guide, see the [How to Create Rules Tutorial](https://pglinter.readthedocs.io/en/latest/tutorial/how_to_create_rules/) in the documentation.

## SARIF Output

Results are generated in SARIF 2.1.0 format:

```json
{
  "version": "2.1.0",
  "runs": [{
    "tool": {
      "driver": {
        "name": "pglinter",
        "version": "1.0.0"
      }
    },
    "results": [{
      "ruleId": "B001",
      "level": "warning",
      "message": {
        "text": "5 tables without primary key exceed threshold: 10%"
      },
      "locations": [{
        "physicalLocation": {
          "artifactLocation": {
            "uri": "database"
          }
        }
      }]
    }]
  }]
}
```

## Conversion from Python

This Rust implementation maintains compatibility with the original Python pglinter while offering:

### Advantages
- **Performance**: 10-100x faster execution
- **Memory Safety**: Rust's memory management
- **Integration**: No external dependencies or connections needed
- **Deployment**: Single extension installation

### Migration Path
1. **Rule Logic**: Direct translation of Python rule logic to Rust
2. **Configuration**: Database-stored instead of YAML files
3. **Output Format**: Same SARIF 2.1.0 format
4. **API**: PostgreSQL functions instead of CLI interface

## Development

```bash
# Run tests
cargo pgrx test

# Development build
cargo pgrx run

# Package for distribution
cargo pgrx package
```

## Documentation

Documentation https://pglinter.readthedocs.io/en/latest/

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add new rules following the established pattern
4. Add tests for your rules
5. Update documentation
6. Submit a pull request

## License

Same as original pglinter project.
