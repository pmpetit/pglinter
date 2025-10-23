#!/bin/bash
set -e

echo "🚀 Starting PostgreSQL..."
su - postgres -c "/usr/lib/postgresql/${PG_MAJOR_VERSION}/bin/pg_ctl -D /var/lib/postgresql/${PG_MAJOR_VERSION}/main -l /var/lib/postgresql/${PG_MAJOR_VERSION}/main/logfile start"

echo "⏳ Waiting for PostgreSQL to be ready..."
until su - postgres -c "/usr/lib/postgresql/${PG_MAJOR_VERSION}/bin/pg_isready -q"; do
    echo "PostgreSQL is not ready yet..."
    sleep 1
done

echo "✅ PostgreSQL is ready!"

echo "📦 Creating pglinter extension..."
if ! su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS pglinter;'"; then
    echo "❌ Failed to create pglinter extension!"
    exit 1
fi

echo "🔍 Testing pglinter installation..."
echo "Testing hello_pglinter:"
if ! su - postgres -c "psql -c 'SELECT hello_pglinter();'"; then
    echo "❌ Failed to get hello from pglinter!"
    exit 1
fi

echo "🎉 pglinter test passed successfully!"

