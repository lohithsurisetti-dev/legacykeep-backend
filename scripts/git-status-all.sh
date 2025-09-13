#!/bin/bash

# Check git status of all repositories

echo "📊 Checking git status of all repositories..."

# Check main repository
echo "Main repository:"
git status --porcelain

# Check service repositories
services=("api-gateway" "auth-service" "user-service" "family-service" "story-service" "media-service" "chat-service" "notification-service")

for service in "${services[@]}"; do
    echo ""
    echo "$service:"
    cd $service
    git status --porcelain
    cd ..
done
