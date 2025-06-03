#!/bin/bash
# Test script for secrets functionality in generate-compose.py

set -e

echo "Testing secrets functionality in generate-compose.py"
echo "==================================================="

# Change to script directory
cd "$(dirname "$0")"

# Test 1: Array format with secrets
echo -e "\n1. Testing array format with secrets..."
python3 generate-compose.py \
    --config-file ../docs/examples/compose-config-secrets.json \
    --output /tmp/compose-secrets-test.yml

echo "Generated compose file:"
cat /tmp/compose-secrets-test.yml

# Test 2: Command line with service secrets
echo -e "\n2. Testing command line with service secrets..."
python3 generate-compose.py \
    --services "api,db" \
    --images '{"api": "myapp/api:latest", "db": "postgres:15"}' \
    --domains "api,db" \
    --ports "8080,5432" \
    --fqdn "example.com" \
    --use-secrets \
    --service-secrets '{"api": ["cloudflare-token", "api-secret"], "db": [{"source": "postgres-password", "target": "/run/secrets/db_password"}]}' \
    --output /tmp/compose-secrets-cli.yml

echo "Generated compose file from CLI:"
cat /tmp/compose-secrets-cli.yml

# Test 3: Mixed configuration (both env-based and explicit secrets)
echo -e "\n3. Testing mixed secrets configuration..."
cat > /tmp/test-mixed-secrets.json << 'EOF'
[
  {
    "service_name": "backend",
    "image": "backend:latest",
    "port": 3000,
    "domain": "backend",
    "environment": {
      "API_KEY": "sensitive-key",
      "DATABASE_PASSWORD": "secret123"
    },
    "secrets": ["ssl-cert", "ssl-key"],
    "use_secrets": true,
    "env": "prod"
  }
]
EOF

python3 generate-compose.py \
    --config-file /tmp/test-mixed-secrets.json \
    --output /tmp/compose-mixed-secrets.yml

echo "Generated compose file with mixed secrets:"
cat /tmp/compose-mixed-secrets.yml

echo -e "\n✅ All tests completed successfully!"