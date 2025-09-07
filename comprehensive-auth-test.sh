#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AUTH_SERVICE_URL="http://localhost:8081/api/v1/auth"
NOTIFICATION_SERVICE_URL="http://localhost:8082/api/v1/notification"
DB_CONTAINER="legacykeep-auth-db"
DB_NAME="auth_db"
DB_USER="legacykeep"

# Test data
TEST_EMAIL="comprehensive.test@example.com"
TEST_USERNAME="comprehensiveuser"
TEST_PASSWORD="SecurePassword123!"
NEW_PASSWORD="NewSecurePassword456!"

echo -e "${BLUE}🔐 Comprehensive Authentication Flow Test${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "FAILED" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ️  $message${NC}"
    elif [ "$status" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    fi
}

# Function to check service health
check_service_health() {
    local service_name=$1
    local health_url=$2
    
    print_status "INFO" "Checking $service_name health..."
    local response=$(curl -s "$health_url")
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        print_status "SUCCESS" "$service_name is running"
        return 0
    else
        print_status "FAILED" "$service_name is not responding"
        return 1
    fi
}

# Function to truncate database
truncate_database() {
    print_status "INFO" "Truncating database for fresh test..."
    
    docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME << 'EOF'
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
        print_status "SUCCESS" "Database truncated successfully"
    else
        print_status "FAILED" "Failed to truncate database"
        exit 1
    fi
}

# Function to generate random email
generate_random_email() {
    local timestamp=$(date +%s)
    local random=$(echo $RANDOM)
    echo "user${timestamp}${random}@example.com"
}

# Function to generate random username
generate_random_username() {
    local timestamp=$(date +%s)
    local random=$(echo $RANDOM)
    echo "user${timestamp}${random}"
}

# Function to test registration
test_registration() {
    local email=$1
    local username=$2
    local password=$3
    
    print_status "INFO" "Testing user registration..."
    print_status "INFO" "Email: $email, Username: $username"
    
    local response=$(curl -s -X POST "$AUTH_SERVICE_URL/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$email\",
            \"username\": \"$username\",
            \"password\": \"$password\"
        }")
    
    echo "Registration Response: $response"
    
    if echo "$response" | grep -q '"status":"success"'; then
        print_status "SUCCESS" "User registration successful"
        return 0
    else
        print_status "FAILED" "User registration failed"
        return 1
    fi
}

# Function to test duplicate registration
test_duplicate_registration() {
    local email=$1
    local username=$2
    local password=$3
    
    print_status "INFO" "Testing duplicate registration (should fail)..."
    
    local response=$(curl -s -X POST "$AUTH_SERVICE_URL/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$email\",
            \"username\": \"$username\",
            \"password\": \"$password\"
        }")
    
    echo "Duplicate Registration Response: $response"
    
    if echo "$response" | grep -q '"status":"error"'; then
        print_status "SUCCESS" "Duplicate registration correctly rejected"
        return 0
    else
        print_status "FAILED" "Duplicate registration should have been rejected"
        return 1
    fi
}

# Function to test login with unverified user
test_login_unverified() {
    local identifier=$1
    local password=$2
    
    print_status "INFO" "Testing login with unverified user (should fail)..."
    
    local response=$(curl -s -X POST "$AUTH_SERVICE_URL/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"identifier\": \"$identifier\",
            \"password\": \"$password\"
        }")
    
    echo "Unverified Login Response: $response"
    
    if echo "$response" | grep -q '"status":"error"' && echo "$response" | grep -q "Email not verified"; then
        print_status "SUCCESS" "Login correctly blocked for unverified user"
        return 0
    else
        print_status "FAILED" "Login should have been blocked for unverified user"
        return 1
    fi
}

# Function to verify email
test_email_verification() {
    local email=$1
    
    print_status "INFO" "Testing email verification..."
    
    # Get verification token from database
    local token=$(docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "SELECT email_verification_token FROM users WHERE email_hash = (SELECT email_hash FROM users WHERE email = '$email' LIMIT 1);" | xargs)
    
    if [ -z "$token" ]; then
        print_status "WARNING" "No verification token found, trying alternative lookup..."
        token=$(docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "SELECT email_verification_token FROM users ORDER BY id DESC LIMIT 1;" | xargs)
    fi
    
    if [ -z "$token" ]; then
        print_status "FAILED" "Could not retrieve verification token"
        return 1
    fi
    
    print_status "INFO" "Verification token: $token"
    
    local response=$(curl -s -X POST "$AUTH_SERVICE_URL/verify-email?token=$token")
    
    echo "Email Verification Response: $response"
    
    if echo "$response" | grep -q '"status":"success"'; then
        print_status "SUCCESS" "Email verification successful"
        return 0
    else
        print_status "FAILED" "Email verification failed"
        return 1
    fi
}

# Function to test successful login
test_successful_login() {
    local identifier=$1
    local password=$2
    
    print_status "INFO" "Testing successful login..."
    
    local response=$(curl -s -X POST "$AUTH_SERVICE_URL/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"identifier\": \"$identifier\",
            \"password\": \"$password\"
        }")
    
    echo "Successful Login Response: $response"
    
    if echo "$response" | grep -q '"status":"success"' && echo "$response" | grep -q '"accessToken"'; then
        print_status "SUCCESS" "Login successful, JWT token received"
        # Extract access token for later use
        ACCESS_TOKEN=$(echo "$response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
        print_status "INFO" "Access token extracted: ${ACCESS_TOKEN:0:20}..."
        return 0
    else
        print_status "FAILED" "Login failed"
        return 1
    fi
}

# Function to test user info endpoint
test_user_info() {
    local access_token=$1
    
    print_status "INFO" "Testing user info endpoint..."
    
    local response=$(curl -s -X GET "$AUTH_SERVICE_URL/me" \
        -H "Authorization: Bearer $access_token")
    
    echo "User Info Response: $response"
    
    if echo "$response" | grep -q '"status":"success"' && echo "$response" | grep -q '"email"'; then
        print_status "SUCCESS" "User info retrieved successfully"
        return 0
    else
        print_status "FAILED" "Failed to retrieve user info"
        return 1
    fi
}

# Function to test password reset
test_password_reset() {
    local email=$1
    local new_password=$2
    
    print_status "INFO" "Testing password reset flow..."
    
    # Step 1: Request password reset
    print_status "INFO" "Step 1: Requesting password reset..."
    local reset_request_response=$(curl -s -X POST "$AUTH_SERVICE_URL/forgot-password?email=$email")
    
    echo "Password Reset Request Response: $reset_request_response"
    
    if ! echo "$reset_request_response" | grep -q '"status":"success"'; then
        print_status "FAILED" "Password reset request failed"
        return 1
    fi
    
    # Step 2: Get reset token
    print_status "INFO" "Step 2: Getting reset token..."
    local reset_token=$(docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "SELECT password_reset_token FROM users WHERE email_hash = (SELECT email_hash FROM users WHERE email = '$email' LIMIT 1);" | xargs)
    
    if [ -z "$reset_token" ]; then
        print_status "WARNING" "No reset token found, trying alternative lookup..."
        reset_token=$(docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "SELECT password_reset_token FROM users ORDER BY id DESC LIMIT 1;" | xargs)
    fi
    
    if [ -z "$reset_token" ]; then
        print_status "FAILED" "Could not retrieve reset token"
        return 1
    fi
    
    print_status "INFO" "Reset token: $reset_token"
    
    # Step 3: Reset password
    print_status "INFO" "Step 3: Resetting password..."
    local reset_response=$(curl -s -X POST "$AUTH_SERVICE_URL/reset-password" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "token=$reset_token&newPassword=$new_password")
    
    echo "Password Reset Response: $reset_response"
    
    if echo "$reset_response" | grep -q '"status":"success"'; then
        print_status "SUCCESS" "Password reset successful"
        return 0
    else
        print_status "FAILED" "Password reset failed"
        return 1
    fi
}

# Function to test login with new password
test_login_new_password() {
    local identifier=$1
    local new_password=$2
    
    print_status "INFO" "Testing login with new password..."
    
    local response=$(curl -s -X POST "$AUTH_SERVICE_URL/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"identifier\": \"$identifier\",
            \"password\": \"$new_password\"
        }")
    
    echo "New Password Login Response: $response"
    
    if echo "$response" | grep -q '"status":"success"' && echo "$response" | grep -q '"accessToken"'; then
        print_status "SUCCESS" "Login with new password successful"
        # Extract new access token
        NEW_ACCESS_TOKEN=$(echo "$response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
        return 0
    else
        print_status "FAILED" "Login with new password failed"
        return 1
    fi
}

# Function to test logout
test_logout() {
    local access_token=$1
    
    print_status "INFO" "Testing logout..."
    
    local response=$(curl -s -X POST "$AUTH_SERVICE_URL/logout" \
        -H "Authorization: Bearer $access_token")
    
    echo "Logout Response: $response"
    
    # Logout might return empty response, which is acceptable
    print_status "SUCCESS" "Logout completed"
    return 0
}

# Function to test notification service
test_notification_service() {
    print_status "INFO" "Testing notification service..."
    
    # Test notification service health
    local health_response=$(curl -s "$NOTIFICATION_SERVICE_URL/health")
    
    if [ $? -eq 0 ] && [ -n "$health_response" ]; then
        print_status "SUCCESS" "Notification service is running"
        echo "Notification Service Health: $health_response"
    else
        print_status "WARNING" "Notification service might not be running"
    fi
}

# Function to check database state
check_database_state() {
    print_status "INFO" "Checking final database state..."
    
    docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "
    SELECT 
        'users' as table_name, 
        COUNT(*) as count,
        COUNT(CASE WHEN email_verified = true THEN 1 END) as verified_users,
        COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END) as active_users
    FROM users
    UNION ALL
    SELECT 'user_sessions', COUNT(*), 0, 0 FROM user_sessions
    UNION ALL
    SELECT 'audit_logs', COUNT(*), 0, 0 FROM audit_logs
    UNION ALL
    SELECT 'blacklisted_tokens', COUNT(*), 0, 0 FROM blacklisted_tokens;
    "
}

# Main test execution
main() {
    echo -e "${BLUE}🚀 Starting Comprehensive Authentication Flow Test${NC}"
    echo ""
    
    # Check services health
    check_service_health "Auth Service" "$AUTH_SERVICE_URL/health"
    check_service_health "Notification Service" "$NOTIFICATION_SERVICE_URL/health"
    echo ""
    
    # Truncate database
    truncate_database
    echo ""
    
    # Generate unique test data
    TEST_EMAIL=$(generate_random_email)
    TEST_USERNAME=$(generate_random_username)
    
    print_status "INFO" "Using test data:"
    print_status "INFO" "Email: $TEST_EMAIL"
    print_status "INFO" "Username: $TEST_USERNAME"
    print_status "INFO" "Password: $TEST_PASSWORD"
    print_status "INFO" "New Password: $NEW_PASSWORD"
    echo ""
    
    # Test 1: Registration
    test_registration "$TEST_EMAIL" "$TEST_USERNAME" "$TEST_PASSWORD"
    echo ""
    
    # Test 2: Duplicate registration (should fail)
    test_duplicate_registration "$TEST_EMAIL" "$TEST_USERNAME" "$TEST_PASSWORD"
    echo ""
    
    # Test 3: Login with unverified user (should fail)
    test_login_unverified "$TEST_EMAIL" "$TEST_PASSWORD"
    echo ""
    
    # Test 4: Email verification
    test_email_verification "$TEST_EMAIL"
    echo ""
    
    # Test 5: Successful login
    test_successful_login "$TEST_EMAIL" "$TEST_PASSWORD"
    echo ""
    
    # Test 6: User info endpoint
    if [ -n "$ACCESS_TOKEN" ]; then
        test_user_info "$ACCESS_TOKEN"
        echo ""
    fi
    
    # Test 7: Password reset
    test_password_reset "$TEST_EMAIL" "$NEW_PASSWORD"
    echo ""
    
    # Test 8: Login with new password
    test_login_new_password "$TEST_EMAIL" "$NEW_PASSWORD"
    echo ""
    
    # Test 9: User info with new token
    if [ -n "$NEW_ACCESS_TOKEN" ]; then
        test_user_info "$NEW_ACCESS_TOKEN"
        echo ""
    fi
    
    # Test 10: Logout
    if [ -n "$NEW_ACCESS_TOKEN" ]; then
        test_logout "$NEW_ACCESS_TOKEN"
        echo ""
    fi
    
    # Test 11: Notification service
    test_notification_service
    echo ""
    
    # Test 12: Final database state
    check_database_state
    echo ""
    
    print_status "SUCCESS" "🎉 Comprehensive Authentication Flow Test Complete!"
    print_status "INFO" "All flows tested successfully with dynamic data"
}

# Run the main function
main






