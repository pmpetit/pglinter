How To Contribute to pglinter
===============================================================================

This project is an **open project**. Any comment or idea is more than welcome.

Here's a few tips to get started if you want to get involved with the pglinter PostgreSQL extension!

Where to start?
------------------------------------------------------------------------------

If you want to help, here are a few ideas:

1. **Testing**: You can install the extension and run extensive tests based on your database use cases. This is very useful to improve the stability of the code. If you can publish your test cases, please add them in the `/tests/sql` directory.

2. **Documentation**: You can write documentation and examples to help new users understand how to use pglinter for database linting and optimization.

3. **Benchmark**: You can run tests on various database setups and measure the impact of the extension on performance.

4. **Rule Development**: Help implement new linting rules or improve existing ones. Check the `src/rules_engine.rs` file to see how rules are structured.

5. **Bug Reports**: If you find issues, please report them with detailed reproduction steps.

6. **Spread the Word**: If you like this extension, let other people know! You can publish a blog post, create a tutorial, or share it on social media.

In any case, let us know how we can help you move forward!

Forking and Contributing
-------------------------------------------------------------------------------

To contribute code to this project, you can simply create your own fork.

### Connect your repo to the upstream

Add a new remote to your local repo:

```bash
git remote add upstream https://github.com/your-username/pglinter.git
```

### Keep your main branch up to date

At any time, you can sync your personal repo like this:

```bash
# switch to the main branch
git checkout main
# download the latest commits from the upstream repo
git fetch upstream
# apply the commits
git rebase upstream/main
# push the changes to your personal repo
git push origin main
```

### Rebase a feature branch

When working on a Pull Request that takes a long time, your local branch might get out of sync:

```bash
# switch to your working branch
git checkout feature-branch
# download the latest commits from the main repo
git fetch upstream
# apply the latest commits
git rebase upstream/main
# push the changes to your personal repo
git push origin feature-branch --force-with-lease
```

Set up a development environment
-------------------------------------------------------------------------------

This extension is written in Rust and SQL using the [PGRX] framework.

To set up your development environment, follow the [PGRX install instructions]!

### System Requirements

1. **Rust toolchain**: Install via [rustup](https://rustup.rs/)
2. **PostgreSQL development headers**:

   ```bash
   # Ubuntu/Debian
   sudo apt install postgresql-server-dev-all

   # RHEL/CentOS/Fedora
   sudo yum install postgresql-devel
   ```

3. **PGRX**: Install the PGRX CLI tool

   ```bash
   cargo install --locked cargo-pgrx
   cargo pgrx init
   ```

### Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/pglinter.git
cd pglinter

# Build the extension
make extension

# Install the extension
make install

# Run tests
make installcheck
```

[PGRX]: https://github.com/pgcentralfoundation/pgrx
[PGRX install instructions]: https://github.com/pgcentralfoundation/pgrx#system-requirements

Adding new linting rules
-------------------------------------------------------------------------------

To add a new linting rule to pglinter, follow these steps:

1. **Design Your Rule**

   - **Determine the scope**: Choose from BASE, CLUSTER, SCHEMA, or TABLE
     - BASE: Database-wide analysis (e.g., overall table statistics)
     - CLUSTER: PostgreSQL cluster configuration (e.g., security settings)
     - SCHEMA: Schema-level checks (e.g., permissions, ownership)
     - TABLE: Individual table analysis (e.g., indexes, foreign keys)
   - **Assign a rule code**: Follow the pattern `[B|C|S|T][XXX]` (e.g., B003, T007)
   - **Set thresholds**: Define warning_level and error_level percentages or counts

2. **Add Rule Definition**

   Add your rule to the `pglinter.rules` table in `sql/rules.sql`:

   ```sql
   (
       rule_id, 'RuleName', 'B999', warning_level, error_level, 'BASE',
       'Description of what this rule checks for.',
       'Message template with {0}, {1} placeholders for dynamic values.',
       ARRAY['suggested fix 1', 'suggested fix 2']
   ),
   ```

3. **Write Rule SQL Queries**

   Rules use one or two SQL queries stored in the `q1` and `q2` columns:

   - **Single Query Rules (q1 only)**: For direct warnings/errors
     - Query should return rows representing issues found
     - Each row triggers a warning/error message

   - **Threshold Rules (q1 + q2)**: For percentage-based analysis
     - `q1`: Query returning total count (denominator)
     - `q2`: Query returning problem count (numerator)
     - Calculates percentage: (q2/q1) * 100

   Update the rule definition in `sql/rules.sql` with your queries:

   ```sql
   UPDATE pglinter.rules SET
   q1 = 'SELECT count(*) FROM pg_tables WHERE schemaname != ''information_schema''',
   q2 = 'SELECT count(*) FROM pg_tables t WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = t.oid AND contype = ''p'')'
   WHERE code = 'B999';
   ```

4. **Test Your Rule**

   - Create a test file in `tests/sql/` (e.g., `b999_my_new_rule.sql`)
   - Include test cases that trigger your rule's warning/error conditions
   - Run the test: `make installcheck REGRESS=b999_my_new_rule`
   - Verify the output matches expected behavior

5. **Rule Execution Flow**

   The pglinter engine automatically:
   - Fetches enabled rules from `pglinter.rules` table
   - Executes appropriate SQL queries based on scope
   - Applies threshold logic for q1+q2 rules
   - Generates SARIF output or console messages

   No additional Rust code is required - the engine handles rule execution dynamically.

Example: Adding Rule B999
-------------------------

```sql
-- Add to sql/rules.sql
INSERT INTO pglinter.rules (
    id, name, code, warning_level, error_level, scope, description, message, fixes, q1, q2
) VALUES (
    999, 'TablesWithoutComments', 'B999', 30, 70, 'BASE',
    'Tables should have descriptive comments for documentation.',
    '{0}/{1} tables without comments exceed {2} threshold: {3}%.',
    ARRAY['Add comments using: COMMENT ON TABLE table_name IS ''description'''],
    'SELECT count(*) FROM pg_tables WHERE schemaname NOT IN (''information_schema'', ''pg_catalog'')',
    'SELECT count(*) FROM pg_tables t LEFT JOIN pg_description d ON d.objoid = t.oid WHERE d.description IS NULL AND t.schemaname NOT IN (''information_schema'', ''pg_catalog'')'
);
```

This process leverages pglinter's dynamic rule execution system - no Rust code changes needed!

Adding new tests
-------------------------------------------------------------------------------

The functional tests are managed with `pg_regress`, a component of the [PGXS] extension framework.

### Quick test workflow

```bash
# Build and install the extension
make extension
make install

# Run all tests
make installcheck

# Run a specific test
make installcheck REGRESS=b001
```

### Adding a new test

Here's how to create a test named `new_test`:

1. **Write your test** in `tests/sql/new_test.sql`:

   ```sql
   -- Test description
   BEGIN;

   CREATE TABLE test_table (id INT, name TEXT);
   CREATE EXTENSION IF NOT EXISTS pglinter;

   -- Test with file output
   SELECT pglinter.perform_base_check('/tmp/test_results.sarif');

   -- Test with prompt output
   SELECT pglinter.perform_base_check();

   ROLLBACK;
   ```

2. **Run the test** to generate output:

   ```bash
   make installcheck REGRESS=new_test
   ```

3. **Check the output** in `results/new_test.out`

4. **If the output is correct**, copy it to expected results:

   ```bash
   cp results/new_test.out tests/expected/
   ```

5. **Add the test** to the `REGRESS_TESTS` variable in `Makefile`

6. **Run all tests** to ensure everything passes:

   ```bash
   make installcheck
   ```

[PGXS]: https://www.postgresql.org/docs/current/extend-pgxs.html

Testing different output modes
-------------------------------------------------------------------------------

pglinter supports two output modes:

### File Output (SARIF format)

```sql
SELECT pglinter.perform_base_check('/tmp/results.sarif');
```

### Prompt Output (formatted notices)

```sql
-- Using NULL or no parameter
SELECT pglinter.perform_base_check();

-- Using convenience functions
SELECT pglinter.check_base();
SELECT pglinter.check_cluster();
SELECT pglinter.check_table();
SELECT pglinter.check_schema();
SELECT pglinter.check_all();
```

### Testing with the Makefile

The Makefile provides several convenience targets:

```bash
# Test specific rules with file output
make test-b001

# Test with prompt output
make test-prompt-b001

# Test convenience functions
make test-convenience

# Test all functionality
make test-all
```

Debug mode
--------------------------------------------------------------------------------

By default, the extension is built with Rust's `--release` mode.

For more verbose output, enable debug mode:

```bash
TARGET=debug make run
```

This provides access to:

- Extension debug logs from `pgrx::debug1!` and `pgrx::debug3!` macros
- Additional debugging information during rule execution

Code Style and Linting
--------------------------------------------------------------------------------

### Pre-commit System

We provide a comprehensive pre-commit system to ensure code quality:

```bash
# Install the git pre-commit hook (recommended)
make install-precommit-hook

# Run all pre-commit checks manually (includes tests)
make precommit

# Run fast pre-commit checks (skips tests, good for rapid development)
make precommit-fast
```

What the pre-commit checks include
----------------------------------

- ✅ Rust code formatting (`cargo fmt --check`)
- ✅ Rust code linting (`cargo clippy`)
- ✅ Markdown documentation linting
- ✅ Unit tests (in full `precommit` target)

### Manual Quality Checks

You can also run individual components:

```bash
# Format code
make fmt

# Check formatting without changing files
make fmt-check

# Run clippy for linting
make lint

# Lint documentation
make lint-docs

# Run security audit
make audit

# Run tests
make test
```

### Rust Code Style

We follow standard Rust conventions:

- Use `cargo fmt` for formatting
- Address all `cargo clippy` warnings
- Write descriptive variable and function names
- Add comments for complex logic

### SQL Code

- Use lowercase for SQL keywords when possible
- Use meaningful table and column aliases
- Comment complex queries
- Follow PostgreSQL best practices

Security Considerations
--------------------------------------------------------------------------------

### SQL Injection Prevention

When adding new rules, be careful about SQL injection risks:

- Use parameterized queries when possible
- Sanitize function parameters
- Use `regclass` and `oid` types instead of literal names for database objects
- Validate input parameters

Example of safe parameter usage:

```rust
let query = "SELECT count(*) FROM pg_tables WHERE schemaname = $1";
for row in client.select(query, None, &[schema_name.into()])? {
    // Process results
}
```

### Function Security

Most functions should be defined as `SECURITY INVOKER`. Use `SECURITY DEFINER` only when absolutely necessary and with extreme care.

Performance Considerations
--------------------------------------------------------------------------------

When implementing new rules:

1. **Avoid expensive queries** on large databases
2. **Use appropriate indexes** in your rule queries
3. **Consider query timeouts** for long-running checks
4. **Test with realistic data volumes**
5. **Use** to verify query performance

Publishing a new Release
--------------------------------------------------------------------------------

1. Update version in `Cargo.toml`
2. Update `pglinter.control` if needed
3. Run full test suite: `make installcheck`
4. Update CHANGELOG.md
5. Create a Git tag
6. Build release packages: `make extension`

Getting Help
--------------------------------------------------------------------------------

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Documentation**: Check the README.md for usage examples

We welcome all contributions, from small bug fixes to major new features!
