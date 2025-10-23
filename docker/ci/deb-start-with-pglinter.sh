#!/bin/bash
set -e

DATA_DIR="/var/lib/postgresql/${PG_MAJOR_VERSION}/main"
PG_BIN="/usr/lib/postgresql/${PG_MAJOR_VERSION}/bin"

if [ ! -d "$DATA_DIR" ]; then
    echo "🛠 Initializing PostgreSQL data directory at $DATA_DIR"
    mkdir -p "$DATA_DIR"
    chown -R postgres:postgres "$(dirname "$DATA_DIR")"
    su - postgres -c "${PG_BIN}/initdb -D $DATA_DIR"
fi

echo "🚀 Starting PostgreSQL..."
su - postgres -c "${PG_BIN}/pg_ctl -D $DATA_DIR -l ${DATA_DIR}/logfile start"

echo "⏳ Waiting for PostgreSQL to be ready..."
until su - postgres -c "${PG_BIN}/pg_isready -q"; do
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

