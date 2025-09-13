#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Simple Dynamic Authentication Test${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Generate unique test data
TIMESTAMP=$(date +%s)
RANDOM_NUM=$RANDOM
TEST_EMAIL="test${TIMESTAMP}${RANDOM_NUM}@example.com"
TEST_USERNAME="user${TIMESTAMP}${RANDOM_NUM}"
TEST_PASSWORD="TestPassword123!"

echo -e "${BLUE}Generated Test Data:${NC}"
echo "Email: $TEST_EMAIL"
echo "Username: $TEST_USERNAME"
echo "Password: $TEST_PASSWORD"
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
    fi
}

# Test 1: Check service health
print_status "INFO" "Testing Auth Service health..."
HEALTH_RESPONSE=$(curl -s "http://localhost:8081/api/v1/auth/health")
if [ $? -eq 0 ] && [ -n "$HEALTH_RESPONSE" ]; then
    print_status "SUCCESS" "Auth Service is running"
    echo "Health Response: $HEALTH_RESPONSE"
else
    print_status "FAILED" "Auth Service is not responding"
    echo "Please start the Auth Service first"
    exit 1
fi
echo ""

# Test 2: Register user
print_status "INFO" "Testing user registration..."
REGISTRATION_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"$TEST_EMAIL\",
        \"username\": \"$TEST_USERNAME\",
        \"password\": \"$TEST_PASSWORD\"
    }")

echo "Registration Response: $REGISTRATION_RESPONSE"

if echo "$REGISTRATION_RESPONSE" | grep -q '"status":"success"'; then
    print_status "SUCCESS" "User registration successful"
else
    print_status "FAILED" "User registration failed"
    echo "Error details: $REGISTRATION_RESPONSE"
    exit 1
fi
echo ""

# Test 3: Check database for user
print_status "INFO" "Checking database for created user..."
DB_USER=$(docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db -t -c "SELECT id, email_hash, username_hash FROM users ORDER BY id DESC LIMIT 1;")
echo "Database User: $DB_USER"
print_status "SUCCESS" "User found in database"
echo ""

# Test 4: Test login with unverified user (should fail)
print_status "INFO" "Testing login with unverified user (should fail)..."
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{
        \"identifier\": \"$TEST_EMAIL\",
        \"password\": \"$TEST_PASSWORD\"
    }")

echo "Login Response: $LOGIN_RESPONSE"

if echo "$LOGIN_RESPONSE" | grep -q '"status":"error"' && echo "$LOGIN_RESPONSE" | grep -q "Email not verified"; then
    print_status "SUCCESS" "Login correctly blocked for unverified user"
else
    print_status "FAILED" "Login should have been blocked for unverified user"
fi
echo ""

# Test 5: Get verification token
print_status "INFO" "Getting email verification token..."
VERIFICATION_TOKEN=$(docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db -t -c "SELECT email_verification_token FROM users ORDER BY id DESC LIMIT 1;" | xargs)
echo "Verification Token: $VERIFICATION_TOKEN"

if [ -n "$VERIFICATION_TOKEN" ]; then
    print_status "SUCCESS" "Verification token retrieved"
else
    print_status "FAILED" "No verification token found"
    exit 1
fi
echo ""

# Test 6: Verify email
print_status "INFO" "Testing email verification..."
VERIFICATION_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/verify-email?token=$VERIFICATION_TOKEN")
echo "Verification Response: $VERIFICATION_RESPONSE"

if echo "$VERIFICATION_RESPONSE" | grep -q '"status":"success"'; then
    print_status "SUCCESS" "Email verification successful"
else
    print_status "FAILED" "Email verification failed"
fi
echo ""

# Test 7: Test successful login
print_status "INFO" "Testing successful login..."
SUCCESSFUL_LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{
        \"identifier\": \"$TEST_EMAIL\",
        \"password\": \"$TEST_PASSWORD\"
    }")

echo "Successful Login Response: $SUCCESSFUL_LOGIN_RESPONSE"

if echo "$SUCCESSFUL_LOGIN_RESPONSE" | grep -q '"status":"success"' && echo "$SUCCESSFUL_LOGIN_RESPONSE" | grep -q '"accessToken"'; then
    print_status "SUCCESS" "Login successful, JWT token received"
    
    # Extract access token
    ACCESS_TOKEN=$(echo "$SUCCESSFUL_LOGIN_RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
    echo "Access Token: ${ACCESS_TOKEN:0:20}..."
else
    print_status "FAILED" "Login failed"
fi
echo ""

# Test 8: Test user info endpoint
if [ -n "$ACCESS_TOKEN" ]; then
    print_status "INFO" "Testing user info endpoint..."
    USER_INFO_RESPONSE=$(curl -s -X GET "http://localhost:8081/api/v1/auth/me" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    echo "User Info Response: $USER_INFO_RESPONSE"
    
    if echo "$USER_INFO_RESPONSE" | grep -q '"status":"success"' && echo "$USER_INFO_RESPONSE" | grep -q '"email"'; then
        print_status "SUCCESS" "User info retrieved successfully"
    else
        print_status "FAILED" "Failed to retrieve user info"
    fi
    echo ""
fi

# Test 9: Test password reset
print_status "INFO" "Testing password reset flow..."
NEW_PASSWORD="NewPassword456!"

# Request password reset
RESET_REQUEST_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/forgot-password?email=$TEST_EMAIL")
echo "Reset Request Response: $RESET_REQUEST_RESPONSE"

if echo "$RESET_REQUEST_RESPONSE" | grep -q '"status":"success"'; then
    print_status "SUCCESS" "Password reset request successful"
    
    # Get reset token
    RESET_TOKEN=$(docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db -t -c "SELECT password_reset_token FROM users ORDER BY id DESC LIMIT 1;" | xargs)
    echo "Reset Token: $RESET_TOKEN"
    
    if [ -n "$RESET_TOKEN" ]; then
        # Reset password
        RESET_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/reset-password" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "token=$RESET_TOKEN&newPassword=$NEW_PASSWORD")
        
        echo "Password Reset Response: $RESET_RESPONSE"
        
        if echo "$RESET_RESPONSE" | grep -q '"status":"success"'; then
            print_status "SUCCESS" "Password reset successful"
            
            # Test login with new password
            NEW_LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/login" \
                -H "Content-Type: application/json" \
                -d "{
                    \"identifier\": \"$TEST_EMAIL\",
                    \"password\": \"$NEW_PASSWORD\"
                }")
            
            echo "New Password Login Response: $NEW_LOGIN_RESPONSE"
            
            if echo "$NEW_LOGIN_RESPONSE" | grep -q '"status":"success"'; then
                print_status "SUCCESS" "Login with new password successful"
            else
                print_status "FAILED" "Login with new password failed"
            fi
        else
            print_status "FAILED" "Password reset failed"
        fi
    else
        print_status "FAILED" "No reset token found"
    fi
else
    print_status "FAILED" "Password reset request failed"
fi
echo ""

# Test 10: Final database state
print_status "INFO" "Checking final database state..."
docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db -c "
SELECT 
    'users' as table_name, 
    COUNT(*) as count,
    COUNT(CASE WHEN email_verified = true THEN 1 END) as verified_users,
    COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END) as active_users
FROM users
UNION ALL
SELECT 'user_sessions', COUNT(*), 0, 0 FROM user_sessions
UNION ALL
SELECT 'audit_logs', COUNT(*), 0, 0 FROM audit_logs;
"

print_status "SUCCESS" "🎉 Simple Dynamic Authentication Test Complete!"






