#!/bin/sh

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

echo "Creating extension inside template1 and postgres databases"
SQL="CREATE EXTENSION IF NOT EXISTS pglinter CASCADE;"
psql --dbname="template1" -c "$SQL"
psql --dbname="postgres" -c "$SQL"
