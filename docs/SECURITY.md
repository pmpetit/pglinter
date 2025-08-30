# Security Considerations

pg_linter analyzes your database structure and configuration, which requires understanding potential security implications and best practices.

## Security Model

### Extension Privileges

pg_linter operates with the privileges of the user who calls its functions:

- **Superuser**: Full access to all analysis features
- **Database Owner**: Access to owned databases
- **Regular User**: Limited to accessible objects

### Data Access

pg_linter analyzes database metadata and structure, NOT actual data:

✅ **What pg_linter accesses:**
- Table and column names
- Index definitions
- Constraint information
- Schema structure
- PostgreSQL configuration (when accessible)
- Database statistics (pg_stat_*)

❌ **What pg_linter does NOT access:**
- Actual row data
- User passwords
- Sensitive application data
- External system information

### File System Access

pg_linter can write SARIF output files when specified:

- Uses PostgreSQL's file writing permissions
- Respects PostgreSQL's `log_directory` and similar settings
- Cannot access arbitrary file system locations

## Security Rules

pg_linter includes several security-focused rules:

### B005: Unsecured Public Schema

Detects when the public schema allows CREATE privileges for all users:

```sql
-- Check public schema security
SELECT pg_linter.explain_rule('B005');

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

### T009: Tables with No Role Grants

Identifies tables without proper access controls:

```sql
-- Find tables without role-based access
SELECT pg_linter.explain_rule('T009');
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
   -- Create dedicated user for pg_linter
   CREATE USER dblinter_scanner WITH PASSWORD 'secure_password';

   -- Grant minimal required permissions
   GRANT CONNECT ON DATABASE mydb TO dblinter_scanner;
   GRANT USAGE ON SCHEMA information_schema TO dblinter_scanner;
   GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO dblinter_scanner;
   ```

2. **Restricted File Access**
   ```sql
   -- Only write to designated log directory
   SELECT pg_linter.perform_base_check('/var/log/dblinter/scan_results.sarif');
   ```

3. **Network Security**
   - Run analysis from trusted networks only
   - Use SSL connections
   - Consider VPN for remote analysis

### CI/CD Security

1. **Secrets Management**
   ```yaml
   # Use secure secret storage
   env:
     DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
     DB_HOST: ${{ secrets.DB_HOST }}
   ```

2. **Limited Scope**
   ```sql
   -- Use read-only user for CI analysis
   CREATE USER ci_dblinter WITH PASSWORD '${CI_PASSWORD}';
   GRANT CONNECT ON DATABASE mydb TO ci_pg_linter;
   GRANT USAGE ON SCHEMA public TO ci_pg_linter;
   -- Grant only SELECT on metadata tables
   ```

3. **Artifact Security**
   ```yaml
   # Limit SARIF artifact exposure
   - name: Upload SARIF results
     uses: github/codeql-action/upload-sarif@v2
     with:
       sarif_file: results.sarif
     if: github.event.pull_request.head.repo.full_name == github.repository
   ```

## Sensitive Information Handling

### Rule T012: Sensitive Column Detection

When the PostgreSQL Anonymizer extension is available, T012 can detect potentially sensitive columns:

```sql
-- Check for sensitive data patterns
SELECT pg_linter.explain_rule('T012');
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

pg_linter can help identify privacy compliance issues:

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

If pg_linter identifies security issues:

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
SELECT pg_linter.disable_rule('B005') -- If public schema use is intentional
```

**Best Practice**: Document why rules are disabled rather than simply turning them off.

## Security Monitoring

### Regular Security Scans

```bash
#!/bin/bash
# security_scan.sh - Regular security analysis

# Run security-focused rules
psql -d mydb -c "
SELECT pg_linter.disable_rule(rule_code)
FROM pg_linter.show_rules()
WHERE rule_code NOT LIKE 'B005'
  AND rule_code NOT LIKE 'C002'
  AND rule_code NOT LIKE 'T009';

SELECT pg_linter.perform_base_check('/var/log/dblinter/security_scan.sarif');
"

# Check for critical issues
if grep -q '"level": "error"' /var/log/dblinter/security_scan.sarif; then
    echo "CRITICAL: Security issues found!"
    # Send alert
fi
```

### Integration with Security Tools

pg_linter SARIF output integrates with:

- **GitHub Security Tab**: Automatic security issue tracking
- **GitLab Security Dashboard**: Centralized security reporting
- **SIEM Systems**: Parse SARIF for security monitoring
- **Vulnerability Scanners**: Include database analysis

## Audit and Compliance Reporting

### Generate Compliance Reports

```sql
-- Security-focused analysis for compliance
SELECT
    rule_code,
    level,
    message,
    count
FROM pg_linter.perform_base_check()
WHERE rule_code IN ('B005', 'C002', 'T009')
ORDER BY
    CASE level
        WHEN 'error' THEN 1
        WHEN 'warning' THEN 2
        ELSE 3
    END;
```

### Documentation for Auditors

Provide auditors with:

1. **pg_linter Configuration**: Which rules are enabled
2. **Analysis Schedule**: How often scans are performed
3. **Issue Resolution**: How security issues are addressed
4. **Access Controls**: Who can run analysis and view results

## Best Practices Summary

1. **Principle of Least Privilege**: Grant minimal required permissions
2. **Regular Monitoring**: Schedule automated security scans
3. **Secure Storage**: Protect SARIF output and configuration
4. **Documentation**: Maintain security procedures and justifications
5. **Integration**: Include pg_linter in broader security strategy
6. **Review**: Regularly review and update security configurations
7. **Training**: Ensure team understands security implications

For additional security guidance, consult your organization's security team and follow PostgreSQL security best practices.
