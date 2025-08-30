# PG Linter Documentation

In recent years, DBAs were more involved with the database engine itself—creating instances, configuring backups, and monitoring systems and also, overseeing developers' activities.
Today, in the DBRE world where databases are cloud-managed, developers and operations teams often work independently, without a dedicated DBA.

So databases objects lives their own life, created by persons that do their best. It can be usefull to be able to detect some wrong desing creation (for example foreign keys created accross differents schemas...). That's what pglinter was created for.

Database linting and analysis for PostgreSQL
===============================================================================

`pglinter` is a PostgreSQL extension that analyzes your database for potential issues, performance problems, and best practice violations. Written in Rust using pgrx, it provides deep integration with PostgreSQL for efficient database analysis.

The project has a **rule-based approach** to database analysis. This means you can enable or disable specific rules and configure thresholds to match your organization's standards and requirements.

The main goal of this extension is to offer **database quality by design**. We believe that database analysis should be integrated into your development workflow, allowing teams to catch potential issues early in the development cycle.

## Key Features

* **Performance Analysis**: Detect unused indexes, missing indexes, and performance bottlenecks
* **Schema Validation**: Check for proper primary keys, foreign key indexing, and schema design
* **Security Auditing**: Identify potential security risks and configuration issues
* **SARIF Output**: Industry-standard reporting format compatible with modern CI/CD tools
* **Configurable Rules**: Enable/disable rules and adjust thresholds based on your needs

## Rule Categories

PG Linter organizes its analysis rules into four main categories:

### Base Rules (B-series)
Database-wide checks that analyze overall database health and structure:
- **B001**: Tables without primary keys
- **B002**: Redundant indexes
- **B003**: Tables without indexes on foreign keys
- **B004**: Unused indexes
- **B005**: Unsecured public schema
- **B006**: Tables with uppercase names/columns

### Cluster Rules (C-series)
PostgreSQL cluster configuration checks:
- **C001**: Memory configuration issues (max_connections * work_mem > available RAM)
- **C002**: Insecure pg_hba.conf entries

### Table Rules (T-series)
Individual table-specific checks:
- **T001**: Individual tables without primary keys
- **T002**: Tables without any indexes
- **T003**: Tables with redundant indexes
- **T004**: Tables with foreign keys not indexed
- **T005**: Tables with potential missing indexes (high sequential scan usage)
- **T006**: Tables with foreign keys referencing other schemas
- **T007**: Tables with unused indexes
- **T008**: Tables with foreign key type mismatches
- **T009**: Tables with no roles granted
- **T010**: Tables using reserved keywords
- **T011**: Tables with uppercase names/columns
- **T012**: Tables with sensitive columns (requires anon extension)

### Schema Rules (S-series)
Schema-level checks:
- **S001**: Schemas without proper privileges
- **S002**: Schemas with public privileges

## Quick Start

1. **Installation**
   ```sql
   CREATE EXTENSION pglinter;
   ```

2. **Run Analysis**
   ```sql
   -- Analyze entire database
   SELECT pglinter.perform_base_check();

   -- Save results to file
   SELECT pglinter.perform_base_check('/path/to/results.sarif');
   ```

3. **Manage Rules**
   ```sql
   -- Show all rules
   SELECT pglinter.show_rules();

   -- Disable a specific rule
   SELECT pglinter.disable_rule('B001');

   -- Get rule explanation
   SELECT pglinter.explain_rule('B002');
   ```

## Documentation Structure

- **[Configuration](configure.md)**: How to configure rules and thresholds
- **[Functions Reference](functions/)**: Complete function reference
- **[Rule Reference](rules/)**: Detailed description of all rules
- **[How-To Guides](how-to/)**: Practical guides for common scenarios
- **[Development](dev/)**: Contributing and development guides

## Integration

pglinter is designed to integrate seamlessly into your development workflow:

- **CI/CD Pipelines**: Use SARIF output with GitHub Actions, GitLab CI, or other tools
- **Database Migrations**: Run checks after schema changes
- **Monitoring**: Schedule regular database health checks
- **Code Reviews**: Include database analysis in your review process

## Support

- **Issues**: [GitHub Issues](https://github.com/yourorg/pglinter/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourorg/pglinter/discussions)
- **Documentation**: This documentation site

## License

pglinter is released under the [LICENSE](../LICENSE) license.
