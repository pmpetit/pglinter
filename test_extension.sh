#!/bin/bash

# Build and test the dblinter PostgreSQL extension
set -e

echo "Building dblinter extension..."
cargo pgrx package

echo "Installing extension..."
sudo cargo pgrx install --pg-config $(which pg_config)

echo "Creating test database..."
createdb dblinter_test || true

echo "Loading extension..."
psql -d dblinter_test -c "CREATE EXTENSION IF NOT EXISTS dblinter;"

echo "Testing base check..."
psql -d dblinter_test -c "SELECT pg_linter.perform_base_check('/tmp/dblinter_base_results.sarif');"

echo "Testing cluster check..."
psql -d dblinter_test -c "SELECT pg_linter.perform_cluster_check('/tmp/dblinter_cluster_results.sarif');"

echo "Testing table check..."
psql -d dblinter_test -c "SELECT pg_linter.perform_table_check('/tmp/dblinter_table_results.sarif');"

echo "Checking SARIF output..."
if [ -f "/tmp/dblinter_base_results.sarif" ]; then
    echo "Base check SARIF output:"
    cat /tmp/dblinter_base_results.sarif | jq .
fi

if [ -f "/tmp/dblinter_cluster_results.sarif" ]; then
    echo "Cluster check SARIF output:"
    cat /tmp/dblinter_cluster_results.sarif | jq .
fi

if [ -f "/tmp/dblinter_table_results.sarif" ]; then
    echo "Table check SARIF output:"
    cat /tmp/dblinter_table_results.sarif | jq .
fi

echo "Test completed!"
