#!/bin/bash

# Build and test the pg_linter PostgreSQL extension
set -e

echo "Building pg_linter extension..."
cargo pgrx package

echo "Installing extension..."
sudo cargo pgrx install --pg-config $(which pg_config)

echo "Creating test database..."
createdb pg_linter_test || true

echo "Loading extension..."
psql -d pg_linter_test -c "CREATE EXTENSION IF NOT EXISTS pg_linter;"

echo "Testing base check..."
psql -d pg_linter_test -c "SELECT pg_linter.perform_base_check('/tmp/pg_linter_base_results.sarif');"

echo "Testing cluster check..."
psql -d pg_linter_test -c "SELECT pg_linter.perform_cluster_check('/tmp/pg_linter_cluster_results.sarif');"

echo "Testing table check..."
psql -d pg_linter_test -c "SELECT pg_linter.perform_table_check('/tmp/pg_linter_table_results.sarif');"

echo "Checking SARIF output..."
if [ -f "/tmp/pg_linter_base_results.sarif" ]; then
    echo "Base check SARIF output:"
    cat /tmp/pg_linter_base_results.sarif | jq .
fi

if [ -f "/tmp/pg_linter_cluster_results.sarif" ]; then
    echo "Cluster check SARIF output:"
    cat /tmp/pg_linter_cluster_results.sarif | jq .
fi

if [ -f "/tmp/pg_linter_table_results.sarif" ]; then
    echo "Table check SARIF output:"
    cat /tmp/pg_linter_table_results.sarif | jq .
fi

echo "Test completed!"
