# GitHub Copilot Instructions for pglinter

## Project Overview

**pglinter** is a PostgreSQL extension written in Rust using pgrx that analyzes databases for potential issues, performance problems, and best practice violations. It's a conversion of the original Python dblinter to provide better performance and deeper PostgreSQL integration.

## Architecture & Key Components

### Core Technologies
- **Language**: Rust 1.88.0+
- **Framework**: pgrx 0.16.1 (PostgreSQL extension framework)
- **PostgreSQL Support**: Versions 13-18 (including 18beta2)
- **Output Format**: SARIF (Static Analysis Results Interchange Format)

### Project Structure
- `src/lib.rs`: Main entry point and PostgreSQL function definitions
- `src/execute_rules.rs`: Rule execution engine and SARIF output generation
- `src/manage_rules.rs`: Rule configuration management
- `src/fixtures.rs`: Test data and fixtures
- `tests/sql/`: SQL test files for rule validation
- `tests/expected/`: Expected output files for regression testing

### Rule Categories
- **B (Base/Database)**: Database-wide checks (indexes, constraints, etc.)
- **C (Cluster)**: PostgreSQL cluster configuration checks (authentication, security)
- **T (Table)**: Individual table analysis
- **S (Schema)**: Schema-level validation

## Coding Standards & Best Practices

### Rust Code Guidelines
1. **Error Handling**: Use `Result<T, E>` types extensively, prefer `?` operator
2. **Memory Safety**: Leverage Rust's ownership system, avoid unnecessary clones
3. **Performance**: Prefer iterators over loops, use `Vec::with_capacity` for known sizes
4. **pgrx Integration**: Use pgrx macros properly (`#[pg_extern]`, `#[pg_schema]`)
5. **Serialization**: Use serde for JSON/YAML with proper derives

### PostgreSQL Integration
1. **SQL Queries**: Use parameterized queries, avoid SQL injection risks
2. **Transactions**: Be explicit about transaction boundaries in rules
3. **Performance**: Consider query performance impact, use EXPLAIN when needed
4. **Compatibility**: Ensure code works across PostgreSQL 13-18

### Rule Development Guidelines
1. **Rule Structure**: Each rule should implement consistent interface
2. **Configuration**: Rules should be configurable via database settings
3. **Documentation**: Include clear descriptions and examples
4. **Testing**: Add comprehensive SQL tests in `tests/sql/`
5. **SARIF Output**: Ensure proper SARIF format with locations and severity

### Code Review Focus Areas

#### Security
- Validate all SQL inputs to prevent injection attacks
- Check privilege escalation in rule execution
- Review authentication and authorization logic (C-category rules)
- Ensure secure handling of configuration data

#### Performance
- Review query efficiency, especially for large databases
- Check for potential N+1 query problems
- Validate memory usage in rule execution loops
- Consider impact on production databases

#### Correctness
- Verify rule logic against PostgreSQL documentation
- Test edge cases and boundary conditions
- Validate SARIF output format compliance
- Check PostgreSQL version compatibility

#### Code Quality
- Ensure proper error handling and propagation
- Review panic-free code (use `Result` types)
- Check for proper resource cleanup
- Validate test coverage completeness

### Testing Standards
1. **SQL Tests**: Create `.sql` files in `tests/sql/` with descriptive names
2. **Expected Outputs**: Maintain `.out` files in `tests/expected/`
3. **Rule Testing**: Test both positive and negative cases
4. **Integration Tests**: Test rule combinations and configurations
5. **Performance Tests**: Include benchmarks for critical paths

### Documentation Requirements
1. **Function Documentation**: Document all public functions with examples
2. **Rule Documentation**: Include purpose, configuration, and examples
3. **SARIF Schema**: Maintain documentation for output format
4. **Configuration**: Document all configurable parameters

### Git & PR Guidelines
1. **Commit Messages**: Use conventional commits format
2. **Branch Names**: Use descriptive names (feature/rule-name, fix/issue-123)
3. **PR Description**: Include rule testing results and performance impact
4. **Breaking Changes**: Clearly document any breaking changes

### Dependencies & Versions
- Keep pgrx version aligned with project requirements
- Update Rust toolchain carefully (currently requires 1.88.0+)
- Maintain PostgreSQL compatibility matrix
- Use stable versions for production dependencies

## Common Patterns to Follow

### Rule Implementation
```rust
pub fn check_rule_name() -> Result<Vec<SarifResult>, String> {
    // Rule logic here
    // Return SARIF-compatible results
}
```

### Error Handling
```rust
// Prefer Result types over panics
match query_result {
    Ok(data) => process_data(data),
    Err(e) => return Err(format!("Query failed: {}", e)),
}
```

### PostgreSQL Function Export
```rust
#[pg_extern]
fn pglinter_function_name() -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
    // Implementation
}
```

## Anti-Patterns to Avoid
1. **Hardcoded Values**: Use configuration parameters instead
2. **Unwrap/Panic**: Always handle errors gracefully
3. **SQL String Concatenation**: Use parameterized queries
4. **Blocking Operations**: Be mindful of database locks
5. **Inconsistent Naming**: Follow PostgreSQL naming conventions

## Performance Considerations
- Rules should be efficient on large databases
- Consider query optimization and indexing requirements
- Be mindful of memory usage during rule execution
- Test performance impact on production-like datasets

When reviewing or generating code for this project, prioritize database safety, performance, and maintainability. Always consider the impact on production PostgreSQL environments.
