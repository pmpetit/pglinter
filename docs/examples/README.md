# pglinter Examples

Practical examples of using pglinter in real-world scenarios.

## Basic Usage Examples

### Simple Database Analysis

```sql
-- Quick health check
SELECT * FROM pglinter.perform_base_check();

-- Save results to file
SELECT pglinter.perform_base_check('/tmp/db_analysis.sarif');

-- Check specific rule
SELECT pglinter.explain_rule('B001');
```

### Rule Management

```sql
-- View all rules
SELECT rule_code, enabled, description
FROM pglinter.show_rules()
ORDER BY rule_code;

-- Enable/disable rules
SELECT pglinter.disable_rule('B005'); -- Public schema security
SELECT pglinter.enable_rule('T004');  -- FK indexing

-- Check rule status
SELECT pglinter.is_rule_enabled('B002');
```

## Configuration Examples

### Development Environment Setup

```sql
-- config/development.sql
\echo 'Configuring pglinter for development environment...'

-- Disable strict rules for development
SELECT pglinter.disable_rule('B005'); -- Public schema
SELECT pglinter.disable_rule('C002'); -- pg_hba security
SELECT pglinter.disable_rule('T009'); -- Role grants
SELECT pglinter.disable_rule('T010'); -- Reserved keywords

-- Enable core data integrity rules
SELECT pglinter.enable_rule('B001');  -- Primary keys
SELECT pglinter.enable_rule('T001');  -- Table primary keys
SELECT pglinter.enable_rule('T004');  -- FK indexing
SELECT pglinter.enable_rule('T008');  -- FK type mismatches

\echo 'Development configuration complete.'
```

### Production Environment Setup

```sql
-- config/production.sql
\echo 'Configuring pglinter for production environment...'

-- Enable all security and performance rules
SELECT pglinter.enable_rule(rule_code)
FROM pglinter.show_rules();

\echo 'Production configuration complete.'
```

### Performance-Focused Configuration

```sql
-- config/performance.sql
\echo 'Configuring pglinter for performance analysis...'

-- Disable non-performance rules
SELECT pglinter.disable_rule(rule_code)
FROM pglinter.show_rules()
WHERE rule_code NOT IN (
    'B002', -- Redundant indexes
    'B004', -- Unused indexes
    'T003', -- Table redundant indexes
    'T005', -- High sequential scans
    'T007'  -- Table unused indexes
);

\echo 'Performance configuration complete.'
```

## CI/CD Integration Examples

### GitHub Actions Workflow

```yaml
# .github/workflows/pglinter.yml
name: Database Linting

on:
  push:
    branches: [main, develop]
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
    - name: Checkout
      uses: actions/checkout@v3

    - name: Setup database schema
      run: |
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -f schema.sql

    - name: Install pglinter
      run: |
        # Add your installation steps here
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -c "CREATE EXTENSION pglinter;"

    - name: Configure for CI
      run: |
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -f config/ci.sql

    - name: Run analysis
      run: |
        PGPASSWORD=postgres psql -h localhost -U postgres -d testdb -c \
          "SELECT pglinter.perform_base_check('/tmp/results.sarif');"

    - name: Upload SARIF
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: /tmp/results.sarif

    - name: Check for critical issues
      run: |
        if grep -q '"level": "error"' /tmp/results.sarif; then
          echo "❌ Critical issues found!"
          exit 1
        fi
```

### GitLab CI Configuration

```yaml
# .gitlab-ci.yml
stages:
  - database-lint

variables:
  POSTGRES_PASSWORD: password
  POSTGRES_DB: testdb

services:
  - postgres:14

db-lint:
  stage: database-lint
  image: postgres:14
  before_script:
    - export PGPASSWORD=$POSTGRES_PASSWORD

  script:
    # Setup
    - psql -h postgres -U postgres -d testdb -f schema.sql
    - psql -h postgres -U postgres -d testdb -c "CREATE EXTENSION pglinter;"
    - psql -h postgres -U postgres -d testdb -f config/ci.sql

    # Analyze
    - psql -h postgres -U postgres -d testdb -c "SELECT pglinter.perform_base_check('/tmp/results.sarif');"

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

```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        DB_HOST = 'localhost'
        DB_NAME = 'testdb'
        DB_USER = 'postgres'
        DB_PASS = credentials('postgres-password')
    }

    stages {
        stage('Database Setup') {
            steps {
                sh '''
                    export PGPASSWORD=$DB_PASS
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f schema.sql
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pglinter;"
                '''
            }
        }

        stage('pglinter Analysis') {
            steps {
                sh '''
                    export PGPASSWORD=$DB_PASS
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f config/jenkins.sql
                    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
                        "SELECT pglinter.perform_base_check('${WORKSPACE}/results.sarif');"
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
            archiveArtifacts artifacts: 'results.sarif'
        }
    }
}
```

## Monitoring and Automation Examples

### Daily Health Check Script

```bash
#!/bin/bash
# daily_check.sh - Daily database health monitoring

set -e

# Configuration
DB_NAME="${DB_NAME:-production_db}"
LOG_DIR="${LOG_DIR:-/var/log/pglinter}"
DATE=$(date +%Y-%m-%d)
EMAIL_ALERT="${EMAIL_ALERT:-admin@company.com}"

# Create log directory
mkdir -p "$LOG_DIR"

echo "Starting daily pglinter analysis for $DB_NAME..."

# Run comprehensive analysis
psql -d "$DB_NAME" -c "
-- Configure for production monitoring
SELECT pglinter.enable_rule(rule_code) FROM pglinter.show_rules();

-- Run all analysis types
SELECT pglinter.perform_base_check('$LOG_DIR/base_$DATE.sarif');
SELECT pglinter.perform_table_check('$LOG_DIR/tables_$DATE.sarif');
SELECT pglinter.perform_cluster_check('$LOG_DIR/cluster_$DATE.sarif');
"

# Count issues by severity
ERRORS=$(grep -r '"level": "error"' "$LOG_DIR"/*_$DATE.sarif 2>/dev/null | wc -l || echo "0")
WARNINGS=$(grep -r '"level": "warning"' "$LOG_DIR"/*_$DATE.sarif 2>/dev/null | wc -l || echo "0")

echo "Analysis complete for $DATE:"
echo "  Errors: $ERRORS"
echo "  Warnings: $WARNINGS"

# Alert on critical issues
if [ "$ERRORS" -gt 0 ]; then
    echo "🚨 CRITICAL: $ERRORS database errors found!"

    # Extract error details
    ERROR_DETAILS=$(grep -A 2 '"level": "error"' "$LOG_DIR"/*_$DATE.sarif | head -20)

    # Send email alert
    {
        echo "Subject: Critical Database Issues - $DATE"
        echo "To: $EMAIL_ALERT"
        echo ""
        echo "Critical database issues found in $DB_NAME:"
        echo ""
        echo "$ERROR_DETAILS"
        echo ""
        echo "Full reports available in: $LOG_DIR"
    } | sendmail "$EMAIL_ALERT"

    # Exit with error for monitoring systems
    exit 1
fi

echo "✅ Daily check completed successfully"
```

### Prometheus Metrics Exporter

```bash
#!/bin/bash
# pglinter_exporter.sh - Export metrics for Prometheus

DB_NAME="${1:-production_db}"
METRICS_FILE="/var/lib/prometheus/node-exporter/pglinter.prom"

echo "Exporting pglinter metrics for $DB_NAME..."

# Run analysis and capture results
ANALYSIS_RESULTS=$(mktemp)
psql -t -d "$DB_NAME" -c "SELECT * FROM pglinter.perform_base_check();" > "$ANALYSIS_RESULTS"

# Initialize metrics file
cat > "$METRICS_FILE" << EOF
# HELP pglinter_issues_total Number of database issues by rule and severity
# TYPE pglinter_issues_total gauge

# HELP pglinter_last_analysis_timestamp Timestamp of last analysis
# TYPE pglinter_last_analysis_timestamp gauge

EOF

# Parse results and create metrics
while IFS='|' read -r rule level message count; do
    # Clean up variables
    rule=$(echo "$rule" | xargs | tr -d ' ')
    level=$(echo "$level" | xargs | tr -d ' ')
    count=$(echo "$count" | xargs | tr -d ' ')

    # Skip empty lines
    if [[ -n "$rule" && -n "$level" && -n "$count" ]]; then
        echo "pglinter_issues_total{rule=\"$rule\",level=\"$level\",database=\"$DB_NAME\"} $count" >> "$METRICS_FILE"
    fi
done < "$ANALYSIS_RESULTS"

# Add timestamp
echo "pglinter_last_analysis_timestamp{database=\"$DB_NAME\"} $(date +%s)" >> "$METRICS_FILE"

# Cleanup
rm -f "$ANALYSIS_RESULTS"

echo "Metrics exported to $METRICS_FILE"
```

### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "pglinter Database Health",
    "panels": [
      {
        "title": "Issues by Severity",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (level) (pglinter_issues_total)",
            "legendFormat": "{{level}}"
          }
        ]
      },
      {
        "title": "Issues by Rule",
        "type": "table",
        "targets": [
          {
            "expr": "pglinter_issues_total > 0",
            "format": "table"
          }
        ]
      },
      {
        "title": "Time Since Last Analysis",
        "type": "stat",
        "targets": [
          {
            "expr": "(time() - pglinter_last_analysis_timestamp) / 3600",
            "legendFormat": "Hours"
          }
        ]
      }
    ]
  }
}
```

## Scripted Analysis Examples

### Multi-Database Analysis

```bash
#!/bin/bash
# analyze_all_databases.sh - Analyze multiple databases

DATABASES=("app_prod" "app_staging" "analytics" "reporting")
ANALYSIS_DATE=$(date +%Y-%m-%d_%H-%M)
REPORT_DIR="/var/log/pglinter/multi-db-$ANALYSIS_DATE"

mkdir -p "$REPORT_DIR"

for db in "${DATABASES[@]}"; do
    echo "Analyzing database: $db"

    # Create database-specific directory
    mkdir -p "$REPORT_DIR/$db"

    # Run analysis
    psql -d "$db" -c "
    -- Configure based on database type
    $(case $db in
        *prod*) echo 'SELECT pglinter.enable_rule(rule_code) FROM pglinter.show_rules();' ;;
        *staging*) echo 'SELECT pglinter.disable_rule(''T010''); SELECT pglinter.disable_rule(''C002'');' ;;
        *analytics*) echo 'SELECT pglinter.disable_rule(''B001''); SELECT pglinter.disable_rule(''T001'');' ;;
    esac)

    SELECT pglinter.perform_base_check('$REPORT_DIR/$db/base.sarif');
    SELECT pglinter.perform_table_check('$REPORT_DIR/$db/tables.sarif');
    "

    echo "✅ Completed analysis for $db"
done

# Generate summary report
echo "Generating summary report..."

{
    echo "# Multi-Database Analysis Report"
    echo "Generated: $(date)"
    echo ""

    for db in "${DATABASES[@]}"; do
        echo "## Database: $db"

        errors=$(grep -c '"level": "error"' "$REPORT_DIR/$db"/*.sarif 2>/dev/null || echo "0")
        warnings=$(grep -c '"level": "warning"' "$REPORT_DIR/$db"/*.sarif 2>/dev/null || echo "0")

        echo "- Errors: $errors"
        echo "- Warnings: $warnings"
        echo ""
    done
} > "$REPORT_DIR/summary.md"

echo "📊 Summary report created: $REPORT_DIR/summary.md"
```

### Schema Migration Validation

```sql
-- migrate_and_validate.sql
-- Use this script to validate schema changes

\echo 'Starting schema migration validation...'

-- Create backup of current rules configuration
CREATE TEMP TABLE rule_backup AS
SELECT rule_code, enabled FROM pglinter.show_rules();

-- Apply migration
\i migration.sql

-- Run pre-migration analysis
\echo 'Running post-migration analysis...'

-- Enable strict rules for migration validation
SELECT pglinter.enable_rule('B001'); -- Primary keys
SELECT pglinter.enable_rule('T001'); -- Table primary keys
SELECT pglinter.enable_rule('T004'); -- FK indexing
SELECT pglinter.enable_rule('T008'); -- FK type mismatches

-- Analyze results
SELECT
    rule_code,
    level,
    message,
    count
FROM (
    SELECT * FROM pglinter.perform_base_check()
    UNION ALL
    SELECT * FROM pglinter.perform_table_check()
) analysis
WHERE level = 'error'
ORDER BY
    CASE level WHEN 'error' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END,
    rule_code;

-- Restore original configuration
SELECT pglinter.disable_rule(rule_code) FROM pglinter.show_rules();
SELECT pglinter.enable_rule(rb.rule_code)
FROM rule_backup rb
WHERE rb.enabled = true;

\echo 'Migration validation complete.'
```

## Reporting Examples

### HTML Report Generation

```python
#!/usr/bin/env python3
# generate_html_report.py

import json
import sys
from datetime import datetime
from pathlib import Path

def generate_html_report(sarif_files, output_file):
    """Generate HTML report from SARIF files."""

    all_results = []

    # Process each SARIF file
    for sarif_file in sarif_files:
        with open(sarif_file) as f:
            sarif_data = json.load(f)

        if 'runs' in sarif_data and sarif_data['runs']:
            results = sarif_data['runs'][0].get('results', [])
            for result in results:
                result['source_file'] = Path(sarif_file).name
                all_results.append(result)

    # Count by severity
    errors = [r for r in all_results if r.get('level') == 'error']
    warnings = [r for r in all_results if r.get('level') == 'warning']
    infos = [r for r in all_results if r.get('level') == 'info']

    # Generate HTML
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>pglinter Analysis Report</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            .summary {{ background: #f5f5f5; padding: 20px; margin-bottom: 30px; border-radius: 5px; }}
            .error {{ color: #d32f2f; font-weight: bold; }}
            .warning {{ color: #f57c00; font-weight: bold; }}
            .info {{ color: #388e3c; }}
            .issue {{ margin: 15px 0; padding: 15px; border-left: 4px solid #ccc; background: #fafafa; }}
            .issue.error {{ border-left-color: #d32f2f; }}
            .issue.warning {{ border-left-color: #f57c00; }}
            .issue.info {{ border-left-color: #388e3c; }}
            .rule-id {{ font-weight: bold; font-size: 1.1em; }}
            .source {{ font-size: 0.9em; color: #666; }}
        </style>
    </head>
    <body>
        <h1>pglinter Analysis Report</h1>
        <p><strong>Generated:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>

        <div class="summary">
            <h2>Summary</h2>
            <p><strong>Total Issues:</strong> {len(all_results)}</p>
            <p class="error">Errors: {len(errors)}</p>
            <p class="warning">Warnings: {len(warnings)}</p>
            <p class="info">Info: {len(infos)}</p>
        </div>

        <h2>Issues</h2>
    """

    # Add issues
    for result in sorted(all_results, key=lambda x: (
        0 if x.get('level') == 'error' else 1 if x.get('level') == 'warning' else 2,
        x.get('ruleId', '')
    )):
        rule_id = result.get('ruleId', 'Unknown')
        level = result.get('level', 'info')
        message = result.get('message', {}).get('text', 'No message')
        source = result.get('source_file', '')

        html += f"""
        <div class="issue {level}">
            <div class="rule-id {level}">Rule {rule_id} ({level.upper()})</div>
            <p>{message}</p>
            <div class="source">Source: {source}</div>
        </div>
        """

    html += """
    </body>
    </html>
    """

    # Write HTML file
    with open(output_file, 'w') as f:
        f.write(html)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: generate_html_report.py output.html input1.sarif [input2.sarif ...]")
        sys.exit(1)

    output_file = sys.argv[1]
    sarif_files = sys.argv[2:]

    generate_html_report(sarif_files, output_file)
    print(f"HTML report generated: {output_file}")
```

### Email Digest Script

```bash
#!/bin/bash
# email_digest.sh - Weekly database health digest

DATABASES=("production" "staging")
REPORT_DATE=$(date +%Y-%m-%d)
TEMP_DIR=$(mktemp -d)

# Generate reports for each database
for db in "${DATABASES[@]}"; do
    echo "Analyzing $db..."

    psql -d "$db" -c "
    SELECT pglinter.perform_base_check('$TEMP_DIR/${db}_base.sarif');
    SELECT pglinter.perform_table_check('$TEMP_DIR/${db}_tables.sarif');
    "
done

# Generate HTML report
python3 generate_html_report.py \
    "$TEMP_DIR/weekly_digest_$REPORT_DATE.html" \
    "$TEMP_DIR"/*.sarif

# Send email
{
    echo "Subject: Weekly Database Health Digest - $REPORT_DATE"
    echo "Content-Type: text/html"
    echo ""
    cat "$TEMP_DIR/weekly_digest_$REPORT_DATE.html"
} | sendmail team@company.com

# Cleanup
rm -rf "$TEMP_DIR"

echo "Weekly digest sent successfully"
```

These examples provide practical patterns for integrating pglinter into various workflows and environments. Adapt them to your specific needs and infrastructure.
