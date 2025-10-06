# Security Considerations

pglinter analyzes your database structure and configuration, which requires understanding potential security implications and best practices.

## Security Model

### Extension Privileges

pglinter operates with the privileges of the user who calls its functions:

- **Superuser**: Full access to all analysis features
- **Database Owner**: Access to owned databases
- **Regular User**: Limited to accessible objects

### Data Access

pglinter analyzes database metadata and structure, NOT actual data:

✅ **What pglinter accesses:**

- Table and column names
- Index definitions
- Constraint information
- Schema structure
- PostgreSQL configuration (when accessible)
- Database statistics (pg_stat_*)

❌ **What pglinter does NOT access:**

- Actual row data
- User passwords
- Sensitive application data
- External system information

### File System Access

pglinter can write SARIF output files when specified:

- Uses PostgreSQL's file writing permissions
- Respects PostgreSQL's `log_directory` and similar settings
- Cannot access arbitrary file system locations

## Security Rules

pglinter includes several security-focused rules:

### B005: Unsecured Public Schema

Detects when the public schema allows CREATE privileges for all users:

```sql
-- Check public schema security
SELECT pglinter.explain_rule('B005');

-- Manual check
SELECT has_schema_privilege('public', 'public', 'CREATE');
```

**Recommendation**: Revoke public CREATE privileges:

```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

### C002: Insecure pg_hba.conf Entries

Identifies potentially insecure authentication configurations:

```sql
-- This rule checks for:
-- - 'trust' authentication methods
-- - Overly broad host ranges
-- - Missing SSL requirements
```

**Recommendations**:

- Use `md5`, `scram-sha-256`, or certificate authentication
- Limit host ranges to specific networks
- Require SSL for remote connections

### C003: MD5 Password Encryption

Detects deprecated MD5 password encryption which prevents upgrades to PostgreSQL 18+:

```sql
-- This rule checks for:
-- - password_encryption = 'md5' setting
-- - Users with MD5-encrypted passwords
```

**Security Concerns**:

- MD5 is cryptographically weak and vulnerable to attacks
- Prevents database upgrades to PostgreSQL 18 and later
- Does not meet modern security compliance requirements

**Recommendations**:

- Change `password_encryption` to `scram-sha-256`
- Reset all user passwords after the change
- Update application connection strings accordingly
- Plan maintenance window for the transition

### T009: Tables with No Role Grants

Identifies tables without proper access controls:

```sql
-- Find tables without role-based access
SELECT pglinter.explain_rule('T009');
```

**Recommendation**: Implement proper role-based access:

```sql
-- Create roles
CREATE ROLE app_read;
CREATE ROLE app_write;

-- Grant appropriate permissions
GRANT SELECT ON TABLE sensitive_table TO app_read;
GRANT SELECT, INSERT, UPDATE ON TABLE user_table TO app_write;
```

## Secure Deployment

### Production Environment

1. **Least Privilege Principle**

   ```sql
   -- Create dedicated user for pglinter
   CREATE USER pglinter_scanner WITH PASSWORD 'secure_password';

   -- Grant minimal required permissions
   GRANT CONNECT ON DATABASE mydb TO pglinter_scanner;
   GRANT USAGE ON SCHEMA information_schema TO pglinter_scanner;
   GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO pglinter_scanner;
   ```

2. **Restricted File Access**

   ```sql
   -- Only write to designated log directory
   SELECT pglinter.perform_base_check('/var/log/pglinter/scan_results.sarif');
   ```

3. **Network Security**
   - Run analysis from trusted networks only
   - Use SSL connections
   - Consider VPN for remote analysis

## Sensitive Information Handling

### Rule T012: Sensitive Column Detection

When the PostgreSQL Anonymizer extension is available, T012 can detect potentially sensitive columns:

```sql
-- Check for sensitive data patterns
SELECT pglinter.explain_rule('T012');
```

**Common sensitive patterns**:

- Email addresses
- Social security numbers
- Credit card numbers
- Personal names
- Addresses

### SARIF Output Security

SARIF files may contain sensitive information:

1. **Schema Information**: Table and column names
2. **Database Names**: Internal database identifiers
3. **Configuration Details**: Server settings

**Recommendations**:

- Store SARIF files securely
- Limit access to analysis results
- Consider sanitizing output for external sharing
- Use encrypted storage for CI/CD artifacts

## Compliance Considerations

### GDPR/Privacy Regulations

pglinter can help identify privacy compliance issues:

1. **Data Discovery**: Identify tables that might contain personal data
2. **Access Controls**: Verify proper role-based access
3. **Retention Policies**: Check for tables without clear data lifecycle

### SOX/Financial Compliance

For financial applications:

1. **Audit Trails**: Ensure tables have proper logging
2. **Access Controls**: Verify segregation of duties
3. **Data Integrity**: Check foreign key constraints

### HIPAA/Healthcare Compliance

For healthcare applications:

1. **PHI Identification**: Detect potential PHI storage
2. **Access Logging**: Verify audit mechanisms
3. **Encryption**: Check for encrypted sensitive columns

## Incident Response

### Security Issue Detection

If pglinter identifies security issues:

1. **Immediate Assessment**
   - Evaluate the severity
   - Determine if data is at risk
   - Check for actual exploitation

2. **Remediation**
   - Apply security fixes immediately
   - Update configurations
   - Re-run analysis to verify fixes

3. **Documentation**
   - Record the issue and resolution
   - Update security procedures
   - Share lessons learned

### False Positive Handling

Sometimes security rules may flag acceptable configurations:

```sql
-- Disable specific rules if justified
SELECT pglinter.disable_rule('B005') -- If public schema use is intentional
```

**Best Practice**: Document why rules are disabled rather than simply turning them off.
