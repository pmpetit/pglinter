# dblinter - PostgreSQL Extension (Rust/pgrx)

This is a conversion of the original Python [dblinter](https://github.com/decathlon/dblinter) to a PostgreSQL extension written in Rust using pgrx.

## Overview
In recent years, DBAs were more involved with the database engine itself—creating instances, configuring backups, and monitoring systems—while also overseeing developers' activities. Today, in the DBRE world where databases are cloud-managed, developers and operations teams often work independently, without a dedicated DBA.
So databases objects lives their own life, created by persons that do their best. It can be usefull to be able to detect some wonrg desing creation (for example foreign keys created accross differents schemas...). That's what dblinter was created for.

dblinter is a PostgreSQL database linter that analyzes your database for potential issues, performance problems, and best practice violations. This Rust implementation provides:

- **Better Performance**: Native Rust performance vs Python
- **Deep Integration**: Runs directly inside PostgreSQL using pgrx
- **SARIF Output**: Industry-standard Static Analysis Results Interchange Format
- **Extensible Rules**: Easy to add new rules using Rust traits

## Architecture

### Rule Categories

- **B (Base/Database)**: Database-wide checks
- **C (Cluster)**: PostgreSQL cluster configuration checks
- **T (Table)**: Individual table checks
- **S (Schema)**: Schema-level checks

### Key Components

1. **Rule Engine** (`rule_engine.rs`): Core engine that executes rules
2. **Rule Trait**: Common interface for all rules
3. **SARIF Generator**: Creates standardized output format
4. **Configuration**: Database-stored rule configurations

## Installation

```bash
# Build the extension
cargo pgrx package

# Install (requires PostgreSQL dev packages)
sudo cargo pgrx install

# Load in your database
psql -d your_database -c "CREATE EXTENSION dblinter;"
```

## Usage

The extension provides four main functions:

```sql
-- Check database-wide issues
SELECT dblinter.perform_base_check('/path/to/base_results.sarif');

-- Check cluster configuration
SELECT dblinter.perform_cluster_check('/path/to/cluster_results.sarif');

-- Check individual tables
SELECT dblinter.perform_table_check('/path/to/table_results.sarif');

-- Check schemas
SELECT dblinter.perform_schema_check('/path/to/schema_results.sarif');
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

### Table Rules (T-series)
- **T001**: Individual tables without primary keys
- **T002**: Tables without any indexes
- **T003-T012**: Additional table-specific checks

### Schema Rules (S-series)
- **S001**: Schemas without proper privileges
- **S002**: Schemas with public privileges

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
        "name": "dblinter",
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

This Rust implementation maintains compatibility with the original Python dblinter while offering:

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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add new rules following the established pattern
4. Add tests for your rules
5. Update documentation
6. Submit a pull request

## License

Same as original dblinter project.
