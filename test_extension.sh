#!/bin/bash

# Build and test the pglinter PostgreSQL extension
set -e

echo "Building pglinter extension..."
cargo pgrx package

echo "Installing extension..."
sudo cargo pgrx install --pg-config $(which pg_config)

echo "Creating test database..."
createdb pglinter_test || true

echo "Loading extension..."
psql -d pglinter_test -c "CREATE EXTENSION IF NOT EXISTS pglinter;"

echo "Testing base check..."
psql -d pglinter_test -c "SELECT pglinter.perform_base_check('/tmp/pglinter_base_results.sarif');"

echo "Testing cluster check..."
psql -d pglinter_test -c "SELECT pglinter.perform_cluster_check('/tmp/pglinter_cluster_results.sarif');"

echo "Testing table check..."
psql -d pglinter_test -c "SELECT pglinter.perform_table_check('/tmp/pglinter_table_results.sarif');"

echo "Checking SARIF output..."
if [ -f "/tmp/pglinter_base_results.sarif" ]; then
    echo "Base check SARIF output:"
    cat /tmp/pglinter_base_results.sarif | jq .
fi

if [ -f "/tmp/pglinter_cluster_results.sarif" ]; then
    echo "Cluster check SARIF output:"
    cat /tmp/pglinter_cluster_results.sarif | jq .
fi

if [ -f "/tmp/pglinter_table_results.sarif" ]; then
    echo "Table check SARIF output:"
    cat /tmp/pglinter_table_results.sarif | jq .
fi

echo "Test completed!"
