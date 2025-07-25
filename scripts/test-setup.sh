#!/bin/bash

echo "🧪 Testing Phase 1 Setup"
echo "========================"

# Test proxy health
echo "1. Testing proxy health..."
curl -s http://localhost:5000/health | python3 -m json.tool

echo -e "\n2. Testing database connection..."
curl -X POST http://localhost:5000/query \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = \"github_monolith\""}' \
  | python3 -m json.tool

echo -e "\n3. Testing table creation..."
curl -X POST http://localhost:5000/query \
  -H "Content-Type: application/json" \
  -d '{"query": "SHOW TABLES"}' \
  | python3 -m json.tool

echo -e "\n Phase 1 testing complete!"