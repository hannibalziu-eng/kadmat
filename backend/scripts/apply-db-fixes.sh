#!/bin/bash

# Script to apply database fixes for Kadmat
# This script will:
# 1. Add seed data for services
# 2. Verify trigger is working

set -e  # Exit on error

echo "🔧 Applying Database Fixes..."
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Get database URL from Supabase config
DATABASE_URL="postgresql://postgres.wwukyrixgkgagofyrlsq:${SUPABASE_SERVICE_ROLE_KEY}@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"

echo "📝 Step 1: Adding seed data for services..."
psql "$DATABASE_URL" -f seed-data.sql

echo ""
echo "✅ Database fixes applied!"
echo ""
echo "🧪 Running verification..."
node scripts/db-verification.js
