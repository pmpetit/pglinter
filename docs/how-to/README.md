# How-To Guides

Practical guides for common pg_linter scenarios and use cases.

## Quick Navigation

- [Setting Up pg_linter in CI/CD](#setting-up-pg_linter-in-cicd)
- [Managing Rules for Different Environments](#managing-rules-for-different-environments)
- [Analyzing Large Databases](#analyzing-large-databases)
- [Integrating with Monitoring Systems](#integrating-with-monitoring-systems)
- [Custom Reporting and Dashboards](#custom-reporting-and-dashboards)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)

## Setting Up pg_linter in CI/CD

### GitHub Actions

Create `.github/workflows/pg_linter.yml`:

```yaml
name: Database Linting
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  database-lint:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup database schema
      run: |
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -f schema.sql

    - name: Install pg_linter
      run: |
        # Add installation steps here
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -c "CREATE EXTENSION pg_linter;"

    - name: Configure rules for CI
      run: |
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -f .pg_linter/ci-config.sql

    - name: Run database analysis
      run: |
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -c \
          "SELECT pg_linter.perform_base_check('/tmp/results.sarif');"

    - name: Upload SARIF results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: /tmp/results.sarif
        category: database-analysis

    - name: Check for critical issues
      run: |
        if grep -q '"level": "error"' /tmp/results.sarif; then
          echo "❌ Critical database issues found!"
          grep -A 5 '"level": "error"' /tmp/results.sarif
          exit 1
        else
          echo "✅ No critical database issues found"
        fi
```

### GitLab CI

Create `.gitlab-ci.yml`:

```yaml
stages:
  - database-lint

variables:
  POSTGRES_PASSWORD: password
  POSTGRES_DB: testdb

services:
  - postgres:14

db-lint:
  stage: database-lint
  image: postgres:14-alpine
  before_script:
    - apk add --no-cache curl
    - export PGPASSWORD=$POSTGRES_PASSWORD

  script:
    # Setup schema
    - psql -h postgres -U postgres -d testdb -f schema.sql

    # Install and configure pg_linter
    - psql -h postgres -U postgres -d testdb -c "CREATE EXTENSION pg_linter;"
    - psql -h postgres -U postgres -d testdb -f .pg_linter/ci-config.sql

    # Run analysis
    - psql -h postgres -U postgres -d testdb -c "SELECT pg_linter.perform_base_check('/tmp/results.sarif');"

    # Check results
    - |
      if grep -q '"level": "error"' /tmp/results.sarif; then
        echo "Critical issues found!"
        exit 1
      fi

  artifacts:
    reports:
      sast: /tmp/results.sarif
    expire_in: 1 week
```

### Jenkins Pipeline

Create `Jenkinsfile`:

```groovy
pipeline {
    agent any

    environment {
        DB_HOST = 'localhost'
        DB_NAME = 'testdb'
        DB_USER = 'postgres'
        DB_PASS = credentials('postgres-password')
    }

    stages {
        stage('Setup Database') {
            steps {
                sh '''
                    export PGPASSWORD=$DB_PASS
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f schema.sql
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pg_linter;"
                '''
            }
        }

        stage('Configure pg_linter') {
            steps {
                sh '''
                    export PGPASSWORD=$DB_PASS
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f .pg_linter/jenkins-config.sql
                '''
            }
        }

        stage('Run Analysis') {
            steps {
                sh '''
                    export PGPASSWORD=$DB_PASS
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
                        "SELECT pg_linter.perform_base_check('${WORKSPACE}/results.sarif');"
                '''
            }
        }

        stage('Process Results') {
            steps {
                publishWarnings parserConfigurations: [[
                    parserName: 'SARIF',
                    pattern: 'results.sarif'
                ]]

                script {
                    def results = readFile('results.sarif')
                    if (results.contains('"level": "error"')) {
                        error("Critical database issues found!")
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'results.sarif', allowEmptyArchive: true
        }
    }
}
```

## Managing Rules for Different Environments

### Environment-Specific Configuration Files

Create configuration files for each environment:

**`.pg_linter/development.sql`**:
```sql
-- Development environment - More permissive
\echo 'Configuring pg_linter for development...'

-- Disable security rules that may not apply in dev
SELECT pg_linter.disable_rule('B005'); -- Public schema
SELECT pg_linter.disable_rule('C002'); -- pg_hba security
SELECT pg_linter.disable_rule('T009'); -- Role grants

-- Focus on data integrity
SELECT pg_linter.enable_rule('B001');  -- Primary keys
SELECT pg_linter.enable_rule('T001');  -- Table primary keys
SELECT pg_linter.enable_rule('T004');  -- FK indexing

\echo 'Development configuration complete.'
```

**`.pg_linter/staging.sql`**:
```sql
-- Staging environment - Production-like but flexible
\echo 'Configuring pg_linter for staging...'

-- Enable most rules but allow some flexibility
SELECT pg_linter.enable_rule(rule_code)
FROM pg_linter.show_rules()
WHERE rule_code NOT IN ('T010', 'C002'); -- Reserved keywords, pg_hba

\echo 'Staging configuration complete.'
```

**`.pg_linter/production.sql`**:
```sql
-- Production environment - Strict rules
\echo 'Configuring pg_linter for production...'

-- Enable all rules for maximum scrutiny
SELECT pg_linter.enable_rule(rule_code)
FROM pg_linter.show_rules();

\echo 'Production configuration complete.'
```

### Conditional Configuration

```sql
-- config/adaptive.sql - Environment-aware configuration
DO $$
DECLARE
    db_name text := current_database();
BEGIN
    IF db_name LIKE '%_dev' OR db_name LIKE '%_development' THEN
        -- Development settings
        PERFORM pg_linter.disable_rule('B005');
        PERFORM pg_linter.disable_rule('C002');
        RAISE NOTICE 'Applied development configuration';

    ELSIF db_name LIKE '%_staging' OR db_name LIKE '%_test' THEN
        -- Staging settings
        PERFORM pg_linter.enable_rule(rule_code)
        FROM pg_linter.show_rules()
        WHERE rule_code NOT IN ('T010', 'C002');
        RAISE NOTICE 'Applied staging configuration';

    ELSE
        -- Production settings (strict)
        PERFORM pg_linter.enable_rule(rule_code)
        FROM pg_linter.show_rules();
        RAISE NOTICE 'Applied production configuration';
    END IF;
END $$;
```

## Analyzing Large Databases

### Chunked Analysis

For very large databases, analyze in chunks:

```sql
-- analyze_by_schema.sql
DO $$
DECLARE
    schema_name text;
    result_file text;
BEGIN
    FOR schema_name IN
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
    LOOP
        result_file := '/tmp/analysis_' || schema_name || '_' ||
                      to_char(now(), 'YYYY-MM-DD') || '.sarif';

        RAISE NOTICE 'Analyzing schema: %', schema_name;

        -- Focus analysis on specific schema
        -- (Note: This would require schema-specific rules in future versions)
        PERFORM pg_linter.perform_table_check(result_file);

        RAISE NOTICE 'Results saved to: %', result_file;
    END LOOP;
END $$;
```

### Performance Optimization

```sql
-- performance_focused.sql - Only run performance-related rules
SELECT pg_linter.disable_rule(rule_code)
FROM pg_linter.show_rules()
WHERE rule_code NOT IN ('B002', 'B004', 'T003', 'T005', 'T007');

-- Run analysis
SELECT pg_linter.perform_base_check('/tmp/performance_analysis.sarif');
SELECT pg_linter.perform_table_check('/tmp/table_performance.sarif');
```

### Scheduled Analysis

```bash
#!/bin/bash
# scheduled_analysis.sh - Daily database analysis

DATE=$(date +%Y-%m-%d)
ANALYSIS_DIR="/var/log/pg_linter"
DB_NAME="production_db"

# Create daily directory
mkdir -p "$ANALYSIS_DIR/$DATE"

# Run different analyses
psql -d $DB_NAME -c "
-- Quick daily check (performance focus)
SELECT pg_linter.disable_rule(rule_code)
FROM pg_linter.show_rules()
WHERE rule_code NOT IN ('B001', 'B002', 'B004', 'T004', 'T005');

SELECT pg_linter.perform_base_check('$ANALYSIS_DIR/$DATE/daily_base.sarif');
SELECT pg_linter.perform_table_check('$ANALYSIS_DIR/$DATE/daily_tables.sarif');
"

# Weekly comprehensive analysis (Sundays)
if [ $(date +%w) -eq 0 ]; then
    psql -d $DB_NAME -c "
    -- Enable all rules for comprehensive weekly check
    SELECT pg_linter.enable_rule(rule_code) FROM pg_linter.show_rules();

    SELECT pg_linter.perform_base_check('$ANALYSIS_DIR/$DATE/weekly_comprehensive.sarif');
    SELECT pg_linter.perform_cluster_check('$ANALYSIS_DIR/$DATE/weekly_cluster.sarif');
    "
fi

# Alert on critical issues
if grep -r '"level": "error"' "$ANALYSIS_DIR/$DATE/"*.sarif; then
    echo "ALERT: Critical database issues found on $DATE" | mail -s "DB Alert" admin@company.com
fi
```

## Integrating with Monitoring Systems

### Prometheus Integration

```bash
#!/bin/bash
# pg_linter_exporter.sh - Export metrics for Prometheus

DB_NAME="mydb"
METRICS_FILE="/var/lib/prometheus/node-exporter/pg_linter.prom"

# Run analysis and extract metrics
RESULT=$(psql -t -d $DB_NAME -c "SELECT * FROM pg_linter.perform_base_check();")

# Parse results and create Prometheus metrics
echo "# HELP pg_linter_issues Number of database issues by rule and severity" > $METRICS_FILE
echo "# TYPE pg_linter_issues gauge" >> $METRICS_FILE

echo "$RESULT" | while IFS='|' read -r rule level message count; do
    # Clean up variables
    rule=$(echo $rule | xargs)
    level=$(echo $level | xargs)
    count=$(echo $count | xargs)

    if [[ -n "$rule" && -n "$level" && -n "$count" ]]; then
        echo "pg_linter_issues{rule=\"$rule\",level=\"$level\"} $count" >> $METRICS_FILE
    fi
done

# Add timestamp
echo "pg_linter_last_analysis_timestamp $(date +%s)" >> $METRICS_FILE
```

### Grafana Dashboard

Create a dashboard with these queries:

```promql
# Total issues by severity
sum by (level) (pg_linter_issues)

# Issues by rule
sum by (rule) (pg_linter_issues)

# Critical issues (errors only)
sum(pg_linter_issues{level="error"})

# Time since last analysis
(time() - pg_linter_last_analysis_timestamp) / 3600
```

### Nagios/Icinga Check

```bash
#!/bin/bash
# check_pg_linter.sh - Nagios check script

DB_NAME="$1"
CRITICAL_THRESHOLD=${2:-1}
WARNING_THRESHOLD=${3:-5}

if [ -z "$DB_NAME" ]; then
    echo "UNKNOWN - Database name required"
    exit 3
fi

# Run analysis and count issues by severity
RESULT=$(psql -t -d $DB_NAME -c "
WITH analysis AS (
    SELECT * FROM pg_linter.perform_base_check()
)
SELECT
    level,
    COUNT(*) as issue_count,
    SUM(COALESCE(count, 1)) as total_count
FROM analysis
GROUP BY level;
")

CRITICAL_COUNT=0
WARNING_COUNT=0
TOTAL_ISSUES=0

while IFS='|' read -r level issue_count total_count; do
    level=$(echo $level | xargs)
    total_count=$(echo $total_count | xargs)

    case $level in
        "error")
            CRITICAL_COUNT=$total_count
            ;;
        "warning")
            WARNING_COUNT=$total_count
            ;;
    esac

    TOTAL_ISSUES=$((TOTAL_ISSUES + total_count))
done <<< "$RESULT"

# Determine exit code and message
if [ $CRITICAL_COUNT -ge $CRITICAL_THRESHOLD ]; then
    echo "CRITICAL - $CRITICAL_COUNT critical database issues found | critical=$CRITICAL_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;; warning=$WARNING_COUNT total=$TOTAL_ISSUES"
    exit 2
elif [ $WARNING_COUNT -ge $WARNING_THRESHOLD ]; then
    echo "WARNING - $WARNING_COUNT database issues found | critical=$CRITICAL_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;; warning=$WARNING_COUNT total=$TOTAL_ISSUES"
    exit 1
else
    echo "OK - $TOTAL_ISSUES minor database issues | critical=$CRITICAL_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;; warning=$WARNING_COUNT total=$TOTAL_ISSUES"
    exit 0
fi
```

## Custom Reporting and Dashboards

### HTML Report Generation

```python
#!/usr/bin/env python3
# generate_report.py - Convert SARIF to HTML

import json
import sys
from datetime import datetime

def sarif_to_html(sarif_file, output_file):
    with open(sarif_file) as f:
        sarif_data = json.load(f)

    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>pg_linter Analysis Report</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            .error {{ color: #d32f2f; font-weight: bold; }}
            .warning {{ color: #f57c00; }}
            .info {{ color: #388e3c; }}
            .summary {{ background-color: #f5f5f5; padding: 15px; margin-bottom: 20px; }}
            .issue {{ margin-bottom: 15px; padding: 10px; border-left: 4px solid #ccc; }}
        </style>
    </head>
    <body>
        <h1>pg_linter Analysis Report</h1>
        <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    """

    if 'runs' in sarif_data and sarif_data['runs']:
        results = sarif_data['runs'][0].get('results', [])

        # Summary
        error_count = sum(1 for r in results if r.get('level') == 'error')
        warning_count = sum(1 for r in results if r.get('level') == 'warning')

        html += f"""
        <div class="summary">
            <h2>Summary</h2>
            <p>Total Issues: {len(results)}</p>
            <p class="error">Errors: {error_count}</p>
            <p class="warning">Warnings: {warning_count}</p>
        </div>

        <h2>Issues</h2>
        """

        # Issues
        for result in results:
            rule_id = result.get('ruleId', 'Unknown')
            level = result.get('level', 'info')
            message = result.get('message', {}).get('text', 'No message')

            html += f"""
            <div class="issue">
                <h3 class="{level}">Rule {rule_id} ({level.upper()})</h3>
                <p>{message}</p>
            </div>
            """

    html += """
    </body>
    </html>
    """

    with open(output_file, 'w') as f:
        f.write(html)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: generate_report.py input.sarif output.html")
        sys.exit(1)

    sarif_to_html(sys.argv[1], sys.argv[2])
    print(f"Report generated: {sys.argv[2]}")
```

### Email Reports

```bash
#!/bin/bash
# email_report.sh - Send email report

DB_NAME="production_db"
REPORT_DATE=$(date +%Y-%m-%d)
SARIF_FILE="/tmp/daily_report_$REPORT_DATE.sarif"
HTML_FILE="/tmp/daily_report_$REPORT_DATE.html"

# Run analysis
psql -d $DB_NAME -c "SELECT pg_linter.perform_base_check('$SARIF_FILE');"

# Generate HTML report
python3 generate_report.py "$SARIF_FILE" "$HTML_FILE"

# Check for critical issues
CRITICAL_COUNT=$(grep -c '"level": "error"' "$SARIF_FILE" || echo "0")

if [ "$CRITICAL_COUNT" -gt 0 ]; then
    SUBJECT="🚨 CRITICAL: Database Issues Found - $REPORT_DATE"
    PRIORITY="high"
else
    SUBJECT="📊 Daily Database Report - $REPORT_DATE"
    PRIORITY="normal"
fi

# Send email
mail -s "$SUBJECT" \
     -a "Content-Type: text/html" \
     -a "X-Priority: $PRIORITY" \
     admin@company.com < "$HTML_FILE"

# Clean up
rm -f "$SARIF_FILE" "$HTML_FILE"
```

## Troubleshooting Common Issues

### Issue: Permission Denied

**Symptoms:**
```
ERROR: permission denied for function perform_base_check
```

**Solutions:**

1. **Grant execution permissions:**
```sql
-- As superuser
GRANT EXECUTE ON FUNCTION pg_linter.perform_base_check(text) TO username;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_linter TO username;
```

2. **Use a privileged user:**
```bash
# Run as postgres user
sudo -u postgres psql -d mydb -c "SELECT pg_linter.perform_base_check();"
```

3. **Check extension installation:**
```sql
-- Verify extension is installed
SELECT * FROM pg_extension WHERE extname = 'pg_linter';

-- Reinstall if necessary
DROP EXTENSION IF EXISTS pg_linter CASCADE;
CREATE EXTENSION pg_linter;
```

### Issue: File Access Errors

**Symptoms:**
```
ERROR: could not open file "/path/to/results.sarif" for writing: Permission denied
```

**Solutions:**

1. **Check directory permissions:**
```bash
# Ensure PostgreSQL can write to directory
sudo chown postgres:postgres /var/log/pg_linter/
sudo chmod 755 /var/log/pg_linter/
```

2. **Use PostgreSQL data directory:**
```sql
-- Write to PostgreSQL-accessible location
SELECT pg_linter.perform_base_check(current_setting('data_directory') || '/pg_linter_results.sarif');
```

3. **Check postgresql.conf settings:**
```
# Add to postgresql.conf if needed
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
```

### Issue: No Results Returned

**Symptoms:**
- Function runs without error but returns no results
- SARIF file is empty or contains no issues

**Solutions:**

1. **Check if rules are enabled:**
```sql
SELECT * FROM pg_linter.show_rules() WHERE enabled = true;
```

2. **Verify database has analyzable objects:**
```sql
-- Check for tables in non-system schemas
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast');
```

3. **Test with a known issue:**
```sql
-- Create a table without primary key to trigger B001
CREATE TABLE test_no_pk (id int, name text);

-- Run analysis
SELECT pg_linter.perform_base_check();

-- Clean up
DROP TABLE test_no_pk;
```

### Issue: Slow Performance

**Symptoms:**
- Analysis takes very long to complete
- High CPU usage during analysis

**Solutions:**

1. **Analyze specific rule categories:**
```sql
-- Run only base rules (usually faster)
SELECT pg_linter.perform_base_check();

-- Skip table rules for large databases initially
SELECT pg_linter.disable_rule(rule_code)
FROM pg_linter.show_rules()
WHERE rule_code LIKE 'T%';
```

2. **Update database statistics:**
```sql
-- Ensure statistics are current
ANALYZE;
```

3. **Run during low-usage periods:**
```bash
# Schedule for off-hours
echo "0 2 * * * psql -d mydb -c \"SELECT pg_linter.perform_base_check('/var/log/pg_linter/nightly.sarif');\"" | crontab -
```

### Issue: Memory Usage

**Symptoms:**
- Out of memory errors during analysis
- PostgreSQL process killed by OOM killer

**Solutions:**

1. **Increase work_mem temporarily:**
```sql
-- Increase memory for analysis session
SET work_mem = '256MB';
SELECT pg_linter.perform_base_check();
RESET work_mem;
```

2. **Analyze in smaller chunks:**
```sql
-- Disable resource-intensive rules
SELECT pg_linter.disable_rule('T005'); -- Sequential scan analysis
SELECT pg_linter.disable_rule('T007'); -- Unused index analysis
```

3. **Check system resources:**
```bash
# Monitor memory during analysis
htop
# Or
watch -n 1 'ps aux | grep postgres'
```

For more specific troubleshooting, check the PostgreSQL logs and consider enabling additional logging:

```sql
-- Enable more verbose logging temporarily
SET log_statement = 'all';
SET log_duration = on;
```
