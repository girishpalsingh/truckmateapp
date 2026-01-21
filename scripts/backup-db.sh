#!/bin/bash

# Script to backup Supabase local database schema
# Usage: ./scripts/backup-db.sh

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Define output file
OUTPUT_FILE="$PROJECT_ROOT/supabase/full_schema_dump.sql"

echo "📦 Backing up Supabase database schema..."
echo "📂 Project Root: $PROJECT_ROOT"
echo "📄 Output File:  $OUTPUT_FILE"

# Check if supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo "❌ Error: 'supabase' CLI not found. Please install it first."
    exit 1
fi

# Run the dump command
cd "$PROJECT_ROOT"
if supabase db dump --local > "$OUTPUT_FILE"; then
    echo "✅ Backup successful!"
    echo "📝 stored in: $OUTPUT_FILE"
    
    # Optional: Create a timestamped copy for archive
    # TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    # cp "$OUTPUT_FILE" "$PROJECT_ROOT/supabase/backups/schema_$TIMESTAMP.sql"
else
    echo "❌ Backup failed!"
    exit 1
fi
