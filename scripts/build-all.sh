#!/bin/bash

# Build all LegacyKeep services

set -e

echo "🏗️ Building all LegacyKeep services..."

services=("api-gateway" "auth-service" "user-service" "family-service" "story-service" "media-service" "chat-service" "notification-service")

for service in "${services[@]}"; do
    echo "Building $service..."
    cd $service
    mvn clean package -DskipTests
    if [ $? -ne 0 ]; then
        echo "❌ Error building $service"
        exit 1
    fi
    cd ..
    echo "✅ $service built successfully"
done

echo "🎉 All services built successfully!"
