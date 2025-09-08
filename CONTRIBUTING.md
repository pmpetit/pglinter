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

- find the level of the rule (Base, Table, Schema, Cluster), and if level are required.
- give a code to the rule.
- add the rule definition to the table pglinter.rules in sql/rules.sql
- create the SQL code in sql/ folder

1. **Create the Rule Logic:**
   - In `src/execute_rules.rs`, add a new function for your rule. For example see [b001](https://github.com/pmpetit/pglinter/blob/9a10fb02639937bd3e187b486ea54303afc28abe/src/execute_rules.rs) rule

2. **Register the Rule for Execution:**
   - Add your rule to the appropriate execution function (e.g., `execute_table_rules`, `execute_base_rules`, etc.):

     ```rust
     if is_rule_enabled("B003").unwrap_or(true) {
         match execute_my_rule() {
             Ok(Some(result)) => results.push(result),
             Ok(None) => {},
             Err(e) => return Err(format!("T013 failed: {}", e)),
         }
     }
     ```

3. **Add SQL for the Rule:**
   - The SQL code for your rule must be placed in the `sql/` directory, in a file named with the rule ID (e.g., `sql/t013.sql`).
   - Embed the SQL in your Rust code using `include_str!` if needed.

4. **Update the Rules Table:**
   - Add your rule to the `pglinter.rules` table with its code, description, and configuration.

5. **Test Your Rule:**
   - Add a test SQL file in `tests/sql/`, run `make installcheck`, and verify the output.

This process ensures your new rule is properly integrated and testable within the pglinter extension.

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
