#!/bin/bash
set -e

# Initialize pglinter extension in PostgreSQL

echo "🚀 Initializing pglinter extension..."

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -p 5432 -U postgres; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done

# Create the extension
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create the pglinter extension
    CREATE EXTENSION IF NOT EXISTS pglinter;

    -- Verify installation
    SELECT extname, extversion FROM pg_extension WHERE extname = 'pglinter';

    -- Show available functions
    \df pglinter.*
EOSQL

echo "✅ pglinter extension initialized successfully!"
