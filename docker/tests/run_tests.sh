#!/bin/bash
set -e

# Test script for pglinter Docker containers
# This script runs basic functionality tests against all PostgreSQL versions

echo "🧪 Running pglinter Docker integration tests..."

# Array of PostgreSQL versions to test
PG_VERSIONS=(13 14 15 16 17)

# Test function
test_pg_version() {
    local version=$1
    local container_name="pglinter-pg${version}"
    local port="54${version}"

    echo "📋 Testing PostgreSQL ${version}..."

    # Check if container is running
    if ! docker ps | grep -q "${container_name}"; then
        echo "❌ Container ${container_name} is not running"
        return 1
    fi

    # Wait for PostgreSQL to be ready
    echo "⏳ Waiting for PostgreSQL ${version} to be ready..."
    for i in {1..30}; do
        if docker exec "${container_name}" pg_isready -U postgres -d pglinter_test >/dev/null 2>&1; then
            echo "✅ PostgreSQL ${version} is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "❌ PostgreSQL ${version} failed to start within 60 seconds"
            return 1
        fi
        sleep 2
    done

    # Run test SQL
    echo "🔬 Running functional tests..."
    if docker exec "${container_name}" psql -U postgres -d pglinter_test -f /tests/basic_test.sql; then
        echo "✅ PostgreSQL ${version} tests passed!"
        return 0
    else
        echo "❌ PostgreSQL ${version} tests failed!"
        return 1
    fi
}

# Main test execution
failed_tests=0

for version in "${PG_VERSIONS[@]}"; do
    if ! test_pg_version "$version"; then
        ((failed_tests++))
    fi
    echo ""
done

# Summary
echo "📊 Test Summary:"
echo "Total versions tested: ${#PG_VERSIONS[@]}"
echo "Failed tests: ${failed_tests}"

if [ $failed_tests -eq 0 ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "❌ Some tests failed!"
    exit 1
fi
