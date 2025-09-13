#!/bin/bash

# Test all LegacyKeep services

set -e

echo "🧪 Testing all LegacyKeep services..."

services=("api-gateway" "auth-service" "user-service" "family-service" "story-service" "media-service" "chat-service" "notification-service")

for service in "${services[@]}"; do
    echo "Testing $service..."
    cd $service
    mvn test
    if [ $? -ne 0 ]; then
        echo "❌ Error testing $service"
        exit 1
    fi
    cd ..
    echo "✅ $service tested successfully"
done

echo "🎉 All services tested successfully!"
