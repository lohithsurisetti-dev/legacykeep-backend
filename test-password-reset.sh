#!/bin/bash

echo "🔐 Testing Password Reset Flow"
echo "=============================="

# Test 1: Request password reset
echo "1. Requesting password reset..."
RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/forgot-password?email=hash.test@example.com")
echo "Response: $RESPONSE"

# Test 2: Get the reset token from database
echo ""
echo "2. Getting reset token from database..."
TOKEN=$(docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db -t -c "SELECT password_reset_token FROM users WHERE id = 1;" | xargs)
echo "Token: $TOKEN"

# Test 3: Reset password with token
echo ""
echo "3. Testing password reset with token..."
RESET_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/reset-password" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=$TOKEN&newPassword=NewPassword123!")
echo "Reset Response: $RESET_RESPONSE"

# Test 4: Check if token was cleared
echo ""
echo "4. Checking if token was cleared..."
CLEARED_TOKEN=$(docker exec -i legacykeep-auth-db psql -U legacykeep -d auth_db -t -c "SELECT password_reset_token FROM users WHERE id = 1;" | xargs)
echo "Token after reset: $CLEARED_TOKEN"

# Test 5: Try login with new password
echo ""
echo "5. Testing login with new password..."
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"identifier": "hash.test@example.com", "password": "NewPassword123!"}')
echo "Login Response: $LOGIN_RESPONSE"

echo ""
echo "✅ Password Reset Test Complete!"
