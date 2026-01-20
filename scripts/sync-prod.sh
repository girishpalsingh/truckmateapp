#!/bin/bash
set -e

# Verify supabase is installed
if ! command -v supabase &> /dev/null; then
    echo "Error: supabase CLI could not be found"
    exit 1
fi

echo "=== Starting Production Sync ==="

echo "1. Dumping production data (auth, public, storage)..."
supabase db dump --linked --data-only --schema auth,public,storage > prod_data.sql

echo "2. Resetting local database..."
# Temporarily move seed.sql to avoid seeding errors during reset
if [ -f supabase/seed.sql ]; then
    mv supabase/seed.sql supabase/seed.sql.bak
fi

# Function to restore seed.sql on exit
cleanup() {
    if [ -f supabase/seed.sql.bak ]; then
        mv supabase/seed.sql.bak supabase/seed.sql
    fi
    if [ -f prod_data.sql ]; then
        rm prod_data.sql
    fi
}
trap cleanup EXIT

# Force reset without confirmation
echo "y" | supabase db reset

echo "3. Importing production data..."
# Use docker exec to import data since psql might not be on host
# Container name derived from inspection: supabase_db_truckmateapp
if docker pgrep -f supabase_db_truckmateapp > /dev/null 2>&1 || docker ps | grep -q supabase_db_truckmateapp; then
    cat prod_data.sql | docker exec -i supabase_db_truckmateapp psql -U postgres
else
    echo "Error: supabase_db_truckmateapp container not found."
    exit 1
fi

echo "=== Sync Complete ==="
echo "Local database now contains production data."
