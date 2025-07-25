#!/bin/bash

echo "🚀 Starting GitHub Data Migration - Phase 1"
echo "============================================"

# Navigate to docker directory
cd "$(dirname "$0")/../docker"

echo "Starting Docker containers..."
docker-compose up -d

echo "Waiting for services to be ready..."
sleep 10

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until docker exec github-monolith mysqladmin ping -h localhost --silent; do
    echo "   MySQL is unavailable - sleeping"
    sleep 2
done
echo "MySQL is ready!"

# Wait for Proxy to be ready
echo "Waiting for SQL Proxy to be ready..."
until curl -s http://localhost:5000/health > /dev/null; do
    echo "   Proxy is unavailable - sleeping"
    sleep 2
done
echo "SQL Proxy is ready!"

echo ""
echo "Phase 1 Setup Complete!"
echo "========================="
echo "SQL Proxy: http://localhost:5000"
echo " MySQL: localhost:3306"
echo "All queries are routing to monolithic database"
echo ""
echo "Test the setup:"
echo "curl -X POST http://localhost:5000/query -H 'Content-Type: application/json' -d '{\"query\": \"SHOW TABLES\"}'"