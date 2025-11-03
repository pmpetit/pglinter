# pglinter - PostgreSQL Extension (Rust/pgrx)

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
# Download and install (replace XX with your PG version: 13, 14, 15, 16, 17, 18)
wget https://github.com/pmpetit/pglinter/releases/download/0.0.17/postgresql_pglinter_XX_0.0.17_amd64.deb
sudo dpkg -i postgresql_pglinter_XX_0.0.17_amd64.deb

# Fix dependencies if needed
sudo apt-get install -f
```

**RHEL/CentOS/Fedora Systems:**

```bash
# Download and install (replace XX with your PG version: 13, 14, 15, 16, 17, 18)
wget https://github.com/pmpetit/pglinter/releases/download/0.0.17/postgresql_pglinter_XX-0.0.17-1.x86_64.rpm
sudo rpm -i postgresql_pglinter_XX-0.0.17-1.x86_64.rpm
# or
sudo yum localinstall postgresql_pglinter_XX-0.0.17-1.x86_64.rpm
```

#### 💻 Usage

After installation, enable the extension in your PostgreSQL database:

```sql
-- Connect to your database
\c your_database

-- Create the extension
CREATE EXTENSION pglinter;

-- Run a basic check
SELECT pglinter.perform_base_check();

-- Check specific rules
SELECT pglinter.check_rule('B001');  -- Tables without primary keys
SELECT pglinter.check_rule('B002');  -- Redundant indexes
```

#### 📋 Available Rules

- **B001-B008**: Base database rules (tables, primary keys, indexes, constraints, etc.)
- **C002**: Cluster security rules
- **S001**: Schema rules

For complete documentation, visit: https://github.com/pmpetit/pglinter/blob/main/docs/functions/README.md

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

## Usage

The extension provides comprehensive database analysis functions with optional file output:

```sql
-- Quick comprehensive check (output to prompt)
SELECT pglinter.check_all();

-- Individual category checks (output to prompt)
SELECT pglinter.check_base();
SELECT pglinter.check_cluster();
SELECT pglinter.check_schema();

-- Generate SARIF reports to files
SELECT pglinter.perform_base_check('/path/to/base_results.sarif');
SELECT pglinter.perform_cluster_check('/path/to/cluster_results.sarif');
SELECT pglinter.perform_schema_check('/path/to/schema_results.sarif');

-- Rule management
SELECT pglinter.show_rules();                    -- Show all rules and status
SELECT pglinter.explain_rule('B001');            -- Get rule details and fixes
SELECT pglinter.enable_rule('B001');             -- Enable specific rule
SELECT pglinter.disable_rule('B001');            -- Disable specific rule
SELECT pglinter.is_rule_enabled('B001');         -- Check rule status
```

## Implemented Rules

### Base Rules (B-series)
- **B001**: Tables without primary keys
- **B002**: Redundant indexes
- **B003**: Tables without indexes on foreign keys
- **B004**: Unused indexes
- **B005**: Unsecured public schema
- **B006**: Tables with uppercase names/columns

### Cluster Rules (C-series)
- **C001**: max_connections * work_mem > available RAM
- **C002**: Insecure pg_hba.conf entries

### Schema Rules (S-series)
- **S001**: Schemas without default role grants
- **S002**: Schemas with environment prefixes/suffixes

## Rule Implementation

Adding a new rule is straightforward:

```rust
pub struct B007Rule; // New rule

impl DatabaseRule for B007Rule {
    fn execute(&self, params: &[RuleParam]) -> spi::Result<Option<RuleResult>> {
        // Your rule logic here
        let query = "SELECT count(*) FROM problematic_tables";

        let result = Spi::connect(|client| {
            // Execute query and analyze results
            // Return RuleResult if issues found
        })?;

        Ok(result)
    }

    fn rule_id(&self) -> &str { "B007" }
    fn scope(&self) -> RuleScope { RuleScope::Base }
    fn name(&self) -> &str { "YourRuleName" }
}

// Register in RuleEngine::new()
rules.insert("B007".to_string(), Box::new(B007Rule));
```

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
