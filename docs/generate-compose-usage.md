# Generate Compose Script Usage Guide

The `generate-compose.py` script is a powerful tool for generating production-ready Docker Compose configurations optimized
for Docker Swarm deployments. It supports advanced features like secrets management, network separation, resource limits,
and Traefik integration.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Configuration Formats](#configuration-formats)
- [Secrets Management](#secrets-management)
- [Command Line Options](#command-line-options)
- [Examples](#examples)
- [Best Practices](#best-practices)

## Overview

The script generates Docker Compose files with:

- **Docker Swarm** optimizations (placement, update configs, rollback configs)
- **Traefik** integration for reverse proxy and SSL
- **Secrets management** for sensitive data
- **Health checks** and monitoring labels
- **Resource limits** and placement constraints
- **Network separation** for security
- **Volume persistence** with proper labeling

### Workflow Integration

This script is used by the GitHub Actions workflows:

- **`generate-compose.yml`** workflow automatically downloads and uses this script
- **`deploy-swarm.yml`** workflow uses it internally when `services_config` is provided
- The script is packaged in releases as `scripts.tar.gz` for workflow consumption

When using the workflows, you don't need to install anything - the workflow handles it automatically.

## Installation

The script requires Python 3.6+ with PyYAML:

```bash
pip install pyyaml
```

## Basic Usage

### Command Line Mode

```bash
python scripts/generate-compose.py \
  --services "api,worker" \
  --images '{"api": "myapp/api:latest", "worker": "myapp/worker:latest"}' \
  --domains "api,worker" \
  --ports "8080,9090" \
  --fqdn "example.com" \
  --output docker-compose.yml
```

### Configuration File Mode

```bash
python scripts/generate-compose.py \
  --config-file config.json \
  --output docker-compose.yml
```

## Configuration Formats

The script supports two configuration formats:

### 1. Array Format (Recommended for Workflows)

```json
[
  {
    "service_name": "api",
    "image": "myapp/api:latest",
    "domain": "api",
    "port": 8080,
    "replicas": 2,
    "environment": {
      "NODE_ENV": "production"
    },
    "secrets": ["api-key", "db-password"]
  }
]
```

### 2. Object Format (Legacy - Command Line Compatible)

```json
{
  "services": ["api", "worker"],
  "images": {
    "api": "myapp/api:latest",
    "worker": "myapp/worker:latest"
  },
  "domains": ["api"],
  "ports": ["8080"],
  "service_secrets": {
    "api": ["api-key", "db-password"]
  }
}
```

## Secrets Management

The script provides comprehensive secrets management with multiple approaches:

### 1. Simple Secret References

```json
{
  "service_name": "api",
  "secrets": ["cloudflare-api-token", "traefik-dashboard-auth"]
}
```

This generates:

```yaml
services:
  api:
    secrets:
      - cloudflare-api-token
      - traefik-dashboard-auth
secrets:
  cloudflare-api-token:
    external: true
  traefik-dashboard-auth:
    external: true
```

### 2. Advanced Secret Configuration

```json
{
  "service_name": "api",
  "secrets": [
    {
      "source": "db-password",
      "target": "/run/secrets/database_password",
      "mode": "0400",
      "uid": "1000",
      "gid": "1000"
    }
  ]
}
```

This generates:

```yaml
services:
  api:
    secrets:
      - source: db-password
        target: /run/secrets/database_password
        mode: '0400'
        uid: '1000'
        gid: '1000'
secrets:
  db-password:
    external: true
```

### 3. Automatic Secret Detection

When `use_secrets: true` is set, the script automatically converts sensitive environment variables to secrets:

```json
{
  "service_name": "api",
  "environment": {
    "API_KEY": "sensitive-value",
    "DATABASE_PASSWORD": "secret123"
  },
  "use_secrets": true,
  "env": "prod"
}
```

This generates:

```yaml
services:
  api:
    environment:
      - API_KEY_FILE=/run/secrets/api_key
      - DATABASE_PASSWORD_FILE=/run/secrets/database_password
    secrets:
      - source: api_api_key
        target: /run/secrets/api_key
        mode: 256
      - source: api_database_password
        target: /run/secrets/database_password
        mode: 256
```

### 4. Command Line Secrets

```bash
python scripts/generate-compose.py \
  --services "api,db" \
  --images '{"api": "myapp:latest", "db": "postgres:15"}' \
  --domains "api,db" \
  --ports "8080,5432" \
  --fqdn "example.com" \
  --use-secrets \
  --service-secrets '{
    "api": ["cloudflare-token", "api-secret"],
    "db": [{"source": "postgres-password", "target": "/run/secrets/db_password"}]
  }'
```

## Command Line Options

### Basic Options

- `--services`: Comma-separated service names
- `--images`: JSON mapping of services to images
- `--domains`: Comma-separated domain prefixes
- `--fqdn`: Fully qualified domain name
- `--replicas`: Number of replicas (default: 1)
- `--ports`: Comma-separated ports
- `--env`: Environment type (dev, staging, prod)
- `--output`: Output file (default: docker-compose.yml)

### Feature Flags

- `--health-checks`: Enable health checks
- `--resource-limits`: Enable resource limits
- `--volume-persistence`: Enable volume persistence
- `--use-secrets`: Use Docker secrets for sensitive data
- `--enable-retry`: Enable Traefik retry middleware
- `--enable-rate-limit`: Enable Traefik rate limiting
- `--enable-monitoring`: Add Prometheus scraping labels
- `--enable-logging`: Enable logging configuration (default: true)
- `--enable-network-separation`: Enable network separation

### Advanced Options

- `--service-envs`: Service environment variables (JSON)
- `--service-secrets`: Per-service secrets configuration (JSON)
- `--service-configs`: Per-service configuration (JSON)
- `--service-resources`: Per-service resource limits (JSON)
- `--service-volumes`: Per-service volume configuration (JSON)
- `--deployment-strategy`: Deployment strategy (rolling, blue-green, canary)
- `--node-constraints`: Node placement constraints (JSON)
- `--advanced-health`: Advanced health check configs (JSON)
- `--retry-config`: Per-service retry configuration (JSON)
- `--rate-limit-config`: Per-service rate limit configuration (JSON)
- `--metrics-paths`: Per-service metrics paths (JSON)
- `--external-networks`: External networks to attach
- `--config-file`: JSON configuration file

## Examples

### 1. Simple API Service

```bash
python scripts/generate-compose.py \
  --services "api" \
  --images '{"api": "myapp/api:latest"}' \
  --domains "api" \
  --ports "8080" \
  --fqdn "example.com" \
  --health-checks \
  --resource-limits
```

### 2. Multi-Service with Secrets

```json
[
  {
    "service_name": "api",
    "image": "myapp/api:latest",
    "port": 8080,
    "domain": "api",
    "replicas": 3,
    "secrets": ["api-key", "db-password"],
    "health_url": "/health",
    "enable_retry": true,
    "enable_rate_limit": true
  },
  {
    "service_name": "worker",
    "image": "myapp/worker:latest",
    "expose": false,
    "replicas": 2,
    "secrets": ["redis-password"],
    "resources": {
      "limits": {"cpus": "1.0", "memory": "1G"}
    }
  }
]
```

### 3. Production Configuration with All Features

```json
[
  {
    "service_name": "frontend",
    "image": "myapp/frontend:latest",
    "port": 3000,
    "domain": "app",
    "replicas": 4,
    "health_checks": true,
    "resource_limits": true,
    "enable_monitoring": true,
    "secrets": [
      "ssl-cert",
      "ssl-key",
      {
        "source": "api-token",
        "target": "/run/secrets/frontend_api_token",
        "mode": "0400"
      }
    ],
    "environment": {
      "NODE_ENV": "production",
      "API_URL": "https://api.example.com"
    },
    "health_url": "/api/health",
    "rate_limit": {
      "average": 200,
      "burst": 100
    },
    "metrics_path": "/metrics",
    "constraints": ["node.labels.type == frontend"],
    "deployment_strategy": "blue-green"
  }
]
```

### 4. Database Service with Volumes and Secrets

```json
{
  "service_name": "postgres",
  "image": "postgres:15",
  "port": 5432,
  "expose": false,
  "replicas": 1,
  "secrets": [
    {
      "source": "postgres-password",
      "target": "/run/secrets/postgres_password"
    },
    {
      "source": "postgres-replication-password",
      "target": "/run/secrets/replication_password"
    }
  ],
  "environment": {
    "POSTGRES_DB": "myapp",
    "POSTGRES_USER": "admin",
    "POSTGRES_PASSWORD_FILE": "/run/secrets/postgres_password"
  },
  "volumes": [
    {
      "name": "postgres_data",
      "path": "/var/lib/postgresql/data",
      "driver": "local",
      "backup": "true"
    }
  ],
  "networks": ["backend", "database"],
  "constraints": ["node.labels.storage == ssd"]
}
```

## Best Practices

### 1. Secrets Management

- Always use external secrets in production
- Create secrets before deployment: `docker secret create <name> <file>`
- Use `_FILE` suffix for environment variables pointing to secret files
- Set appropriate permissions (mode, uid, gid) for secrets

### 2. Service Configuration

- Use explicit `expose: false` for internal services
- Configure appropriate health checks for each service
- Set resource limits to prevent resource exhaustion
- Use placement constraints for specialized workloads

### 3. Network Security

- Enable network separation for production environments
- Use internal networks for backend communication
- Only expose necessary services through Traefik

### 4. Deployment Strategy

- Use `rolling` for standard deployments
- Use `blue-green` for zero-downtime deployments
- Use `canary` for gradual rollouts

### 5. Monitoring and Logging

- Enable monitoring labels for Prometheus integration
- Configure appropriate log rotation
- Use structured logging with proper labels

## Troubleshooting

### Common Issues

1. **Secrets not found**: Ensure external secrets are created before deployment
2. **Network conflicts**: Check for existing networks with `docker network ls`
3. **Resource constraints**: Verify node resources with `docker node ls`
4. **Health check failures**: Test health endpoints manually first

### Debug Mode

Run with Python's verbose flag for detailed output:

```bash
python -v scripts/generate-compose.py --config-file config.json
```

### Validation

Validate generated compose file:

```bash
docker compose -f docker-compose.yml config
```

Deploy to Swarm:

```bash
docker stack deploy -c docker-compose.yml myapp
```
