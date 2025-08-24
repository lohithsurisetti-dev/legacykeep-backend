#!/bin/bash

# =============================================================================
# LegacyKeep Database Truncation Script
# =============================================================================
# This script truncates all tables in the auth service database for testing purposes.
# Use with caution - this will delete ALL data!

echo "🗑️  LegacyKeep Database Truncation Script"
echo "=========================================="
echo ""

# Check if PostgreSQL container is running
if ! docker ps | grep -q "legacykeep-auth-db"; then
    echo "❌ PostgreSQL container 'legacykeep-auth-db' is not running!"
    echo "Please start the database first:"
    echo "  cd auth-service && docker-compose up -d postgres"
    exit 1
fi

echo "⚠️  WARNING: This will delete ALL data from the auth service database!"
echo "Database: auth_db"
echo ""

# Ask for confirmation
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Operation cancelled."
    exit 0
fi

echo ""
echo "🔄 Truncating database tables..."

# Connect to PostgreSQL and truncate all tables
docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db << 'EOF'
-- Disable foreign key checks temporarily
SET session_replication_role = replica;

-- Truncate all tables
TRUNCATE TABLE audit_logs CASCADE;
TRUNCATE TABLE user_sessions CASCADE;
TRUNCATE TABLE blacklisted_tokens CASCADE;
TRUNCATE TABLE users CASCADE;

-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- Reset sequences
ALTER SEQUENCE users_id_seq RESTART WITH 1;
ALTER SEQUENCE user_sessions_id_seq RESTART WITH 1;
ALTER SEQUENCE audit_logs_id_seq RESTART WITH 1;
ALTER SEQUENCE blacklisted_tokens_id_seq RESTART WITH 1;

-- Verify tables are empty
SELECT 'users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'user_sessions', COUNT(*) FROM user_sessions
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs
UNION ALL
SELECT 'blacklisted_tokens', COUNT(*) FROM blacklisted_tokens;
EOF

if [ $? -eq 0 ]; then
    echo "✅ Database truncated successfully!"
    echo ""
    echo "📊 Current table counts:"
    docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db -c "
    SELECT 'users' as table_name, COUNT(*) as count FROM users
    UNION ALL
    SELECT 'user_sessions', COUNT(*) FROM user_sessions
    UNION ALL
    SELECT 'audit_logs', COUNT(*) FROM audit_logs
    UNION ALL
    SELECT 'blacklisted_tokens', COUNT(*) FROM blacklisted_tokens;
    "
else
    echo "❌ Failed to truncate database!"
    exit 1
fi

echo ""
echo "🎉 Database is now clean and ready for testing!"
echo "You can now start the auth service and test the hash-based authentication flow."
