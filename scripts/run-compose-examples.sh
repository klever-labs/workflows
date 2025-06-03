#!/bin/bash
# Script to actually run generate-compose.py with example configurations

set -e

# Create a temporary directory for the virtual environment
TEMP_DIR=$(mktemp -d)
python3 -m venv "$TEMP_DIR/venv"
# shellcheck source=/dev/null
source "$TEMP_DIR/venv/bin/activate"

# Install PyYAML in the temporary environment
pip install --quiet pyyaml


echo "🎯 Running Docker Compose Generation Examples"
echo "==========================================="
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    exit 1
fi

# Create temporary directory for examples
EXAMPLES_DIR="compose-examples"
mkdir -p "$EXAMPLES_DIR"

# Function to run the actual generator
run_example() {
    local example_name=$1
    local description=$2
    local output_file="$EXAMPLES_DIR/${example_name}.yml"
    
    echo "📋 Example: $example_name"
    echo "Description: $description"
    echo ""
    
    # Run the actual command
    if python3 scripts/generate-compose.py \
        --output "$output_file" \
        "${@:3}" 2>&1; then
        echo "✅ Generated successfully!"
        echo ""
        echo "Preview (first 30 lines):"
        echo "----------------------------------------"
        head -30 "$output_file"
        echo "----------------------------------------"
        echo ""
    else
        echo "❌ Generation failed. This might be due to missing PyYAML dependency."
        echo "   Install with: pip3 install pyyaml"
        echo ""
    fi
}

# Example 1: Simple API deployment (production)
cat > "$EXAMPLES_DIR/simple-api-prod.json" << 'EOF'
[
  {
    "service_name": "api",
    "image": "gcr.io/myproject/api:v1.0.0",
    "port": 8080,
    "domain": "api",
    "health_url": "/health",
    "replicas": 3,
    "resource_limits": true,
    "health_checks": true,
    "env": "prod",
    "fqdn": "example.com"
  }
]
EOF

run_example "simple-api-prod" \
    "Single API service in production" \
    --config-file "$EXAMPLES_DIR/simple-api-prod.json"

# Example 2: Multi-service application (staging)
cat > "$EXAMPLES_DIR/multi-service-staging.json" << 'EOF'
[
  {
    "service_name": "frontend",
    "image": "ghcr.io/org/frontend:develop",
    "port": 3000,
    "domain": "app",
    "health_url": "/",
    "health_checks": true,
    "env": "staging",
    "fqdn": "staging.example.com"
  },
  {
    "service_name": "api",
    "image": "ghcr.io/org/api:develop",
    "port": 8080,
    "domain": "api",
    "health_url": "/health",
    "environment": {
      "DATABASE_URL": "postgres://staging-db:5432/app",
      "LOG_LEVEL": "debug"
    },
    "volume_persistence": true,
    "volume_dir": "/data"
  },
  {
    "service_name": "worker",
    "image": "ghcr.io/org/worker:develop",
    "expose": false,
    "health_url": "/status",
    "environment": {
      "QUEUE_NAME": "staging-jobs",
      "CONCURRENCY": "5"
    },
    "volume_persistence": true
  }
]
EOF

run_example "multi-service-staging" \
    "Frontend, API, and worker services in staging" \
    --config-file "$EXAMPLES_DIR/multi-service-staging.json"

# Example 3: Microservices with different configurations
cat > "$EXAMPLES_DIR/microservices-dev.json" << 'EOF'
[
  {
    "service_name": "auth",
    "image": "localhost:5000/auth:latest",
    "port": 8000,
    "domain": "auth",
    "health_url": "/health",
    "environment": {
      "JWT_SECRET": "dev-secret",
      "TOKEN_EXPIRY": "3600"
    },
    "health_checks": true,
    "env": "dev",
    "fqdn": "dev.company.internal"
  },
  {
    "service_name": "user-api",
    "image": "localhost:5000/user-api:latest",
    "port": 8001,
    "domain": "users",
    "health_url": "/api/health",
    "environment": {
      "DB_HOST": "dev-db",
      "CACHE_ENABLED": "false"
    }
  },
  {
    "service_name": "product-api",
    "image": "localhost:5000/product-api:latest",
    "port": 8002,
    "domain": "products",
    "health_url": "/api/health",
    "environment": {
      "ELASTICSEARCH_URL": "http://es-dev:9200"
    }
  },
  {
    "service_name": "search",
    "image": "localhost:5000/search:latest",
    "port": 8003,
    "domain": "search",
    "health_url": "/health",
    "environment": {
      "INDEX_NAME": "products_dev"
    }
  },
  {
    "service_name": "cache-worker",
    "image": "localhost:5000/cache-worker:latest",
    "expose": false,
    "health_url": "/metrics",
    "environment": {
      "REDIS_URL": "redis://dev-redis:6379",
      "WORKER_THREADS": "2"
    }
  }
]
EOF

run_example "microservices-dev" \
    "Complex microservices setup for development" \
    --config-file "$EXAMPLES_DIR/microservices-dev.json"

# Example 4: High-availability production setup
cat > "$EXAMPLES_DIR/ha-production.json" << 'EOF'
[
  {
    "service_name": "web",
    "image": "gcr.io/prod-project/web:v2.1.0",
    "port": 80,
    "domain": "www",
    "health_url": "/healthz",
    "replicas": 5,
    "resource_limits": true,
    "health_checks": true,
    "volume_persistence": true,
    "volume_dir": "/var/lib/app",
    "environment": {
      "CDN_URL": "https://cdn.myapp.com",
      "API_ENDPOINT": "https://api.myapp.com"
    },
    "env": "prod",
    "fqdn": "myapp.com"
  },
  {
    "service_name": "api",
    "image": "gcr.io/prod-project/api:v2.1.0",
    "port": 8080,
    "domain": "api",
    "health_url": "/api/v1/health",
    "replicas": 5,
    "resource_limits": true,
    "environment": {
      "DATABASE_POOL_SIZE": "20",
      "RATE_LIMIT": "1000",
      "ENABLE_METRICS": "true"
    }
  }
]
EOF

run_example "ha-production" \
    "High-availability setup with resource limits" \
    --config-file "$EXAMPLES_DIR/ha-production.json"

# Example 5: Simple services
cat > "$EXAMPLES_DIR/simple-services.json" << 'EOF'
[
  {
    "service_name": "api",
    "image": "myapp/api:v1.0",
    "port": 8080,
    "domain": "api",
    "environment": {
      "DATABASE_URL": "postgres://db:5432/myapp"
    },
    "health_url": "/api/health",
    "replicas": 3,
    "resource_limits": true
  },
  {
    "service_name": "worker",
    "image": "myapp/worker:v1.0",
    "expose": false,
    "networks": ["backend"],
    "environment": {
      "DATABASE_URL": "postgres://db:5432/myapp",
      "WORKER_THREADS": "4"
    }
  }
]
EOF

run_example "simple-services" \
    "Simple API + Worker services" \
    --config-file "$EXAMPLES_DIR/simple-services.json"

# Example 6: Complex production setup
cat > "$EXAMPLES_DIR/production-complete.json" << 'EOF'
[
  {
    "service_name": "api",
    "image": "gcr.io/project/api:v2.0",
    "port": 8080,
    "domain": "api",
    "expose": true,
    "networks": ["traefik-public", "backend", "shared-db"],
    "environment": {
      "NODE_ENV": "production",
      "DATABASE_URL": "postgres://shared-db:5432/myapp",
      "API_SECRET": "secret123"
    },
    "health_url": "/api/health",
    "metrics_path": "/api/metrics",
    "replicas": 3,
    "resources": {
      "limits": {"cpus": "2", "memory": "2G"},
      "reservations": {"cpus": "1", "memory": "1G"}
    },
    "retry": {"attempts": 5, "interval": "200ms"},
    "rate_limit": {"average": 200, "burst": 100},
    "enable_monitoring": true,
    "enable_retry": true,
    "enable_rate_limit": true,
    "use_secrets": true,
    "env": "prod",
    "fqdn": "example.com"
  },
  {
    "service_name": "frontend",
    "image": "gcr.io/project/frontend:v2.0",
    "port": 3000,
    "domain": "app",
    "networks": ["traefik-public"],
    "environment": {
      "NEXT_PUBLIC_API_URL": "https://api.example.com"
    },
    "health_url": "/health",
    "replicas": 2
  },
  {
    "service_name": "payment-worker",
    "image": "gcr.io/project/payment-worker:v2.0",
    "expose": false,
    "networks": ["backend", "payment-gateway", "shared-db"],
    "internal_port": 9000,
    "environment": {
      "PAYMENT_API_KEY": "pk_live_xxx",
      "PAYMENT_SECRET": "sk_live_xxx"
    },
    "resources": {
      "limits": {"cpus": "2", "memory": "2G"}
    },
    "retry": {"attempts": 5, "interval": "500ms"},
    "metrics_path": "/internal/metrics"
  },
  {
    "service_name": "cache",
    "image": "redis:7-alpine",
    "expose": false,
    "networks": ["backend"],
    "internal_port": 6379,
    "volumes": [
      {
        "name": "redis_data",
        "path": "/data",
        "driver": "local"
      }
    ],
    "resources": {
      "limits": {"cpus": "1", "memory": "1G"}
    }
  }
]
EOF

run_example "production-complete" \
    "Production setup with all features" \
    --config-file "$EXAMPLES_DIR/production-complete.json"

# Example 7: Microservices architecture
cat > "$EXAMPLES_DIR/microservices-arch.json" << 'EOF'
[
  {
    "service_name": "auth",
    "image": "services/auth:v2.0",
    "port": 8000,
    "domain": "auth",
    "networks": ["traefik-public", "backend"],
    "environment": {
      "JWT_SECRET": "secret123",
      "TOKEN_EXPIRY": "3600"
    },
    "health_url": "/health",
    "enable_monitoring": true,
    "enable_retry": true,
    "env": "staging",
    "fqdn": "staging.example.com"
  },
  {
    "service_name": "user-api",
    "image": "services/users:v2.0",
    "port": 8001,
    "domain": "users",
    "networks": ["traefik-public", "backend", "user-db"],
    "environment": {
      "DATABASE_URL": "postgres://user-db:5432/users"
    },
    "health_url": "/api/health"
  },
  {
    "service_name": "analytics-job",
    "image": "services/analytics:v2.0",
    "expose": false,
    "networks": ["backend", "analytics-db"],
    "internal_port": 9002,
    "environment": {
      "ANALYTICS_DB_URL": "clickhouse://analytics-db:8123/analytics",
      "BATCH_SIZE": "10000"
    },
    "resources": {
      "limits": {"cpus": "4", "memory": "8G"}
    },
    "volumes": [
      {
        "name": "analytics_temp",
        "path": "/tmp/analytics",
        "driver": "local"
      }
    ]
  }
]
EOF

run_example "microservices-arch" \
    "Microservices architecture" \
    --config-file "$EXAMPLES_DIR/microservices-arch.json"

# Summary
echo "=========================================="
echo "📁 Examples directory: $EXAMPLES_DIR/"
echo ""

if ls "$EXAMPLES_DIR"/*.yml &> /dev/null; then
    echo "Generated files:"
    find "$EXAMPLES_DIR" -maxdepth 1 -name "*.yml" -type f | while read -r file; do
        size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file")
        echo "  - $file ($size bytes)"
    done
    echo ""
    if ls "$EXAMPLES_DIR"/*.json &> /dev/null; then
        echo "Configuration files (JSON format):"
        find "$EXAMPLES_DIR" -maxdepth 1 -name "*.json" -type f | while read -r file; do
            size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file")
            echo "  - $file ($size bytes)"
        done
        echo ""
    fi
    echo "To view a complete example:"
    echo "  cat $EXAMPLES_DIR/simple-api-prod.yml"
    echo ""
    echo "To view configuration files:"
    echo "  cat $EXAMPLES_DIR/simple-api-prod.json"
    echo ""
    echo "To validate generated YAML:"
    echo "  python3 -c 'import yaml, sys; yaml.safe_load(open(sys.argv[1]))' <file.yml>"
else
    echo "⚠️  No files were generated. Please install PyYAML:"
    echo ""
    echo "  # On macOS with Homebrew Python:"
    echo "  python3 -m pip install --user pyyaml"
    echo ""
    echo "  # Or in a virtual environment:"
    echo "  python3 -m venv venv"
    echo "  source venv/bin/activate"
    echo "  pip install pyyaml"
fi


# Deactivate and remove the temporary environment
deactivate
rm -rf "$TEMP_DIR"