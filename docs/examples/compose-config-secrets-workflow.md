# Using Secrets with Deploy Swarm Workflow

This guide demonstrates how to use Docker Swarm secrets with the `deploy-swarm.yml` reusable workflow.

## Overview

The workflow supports Docker Swarm secrets through the `services_config` input. You can define secrets for each service
using either simple string format or advanced configuration with custom permissions.

## Basic Example with Secrets

```yaml
name: Deploy with Secrets

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'my-secure-app'
      environment_type: 'prod'
      services_config: |
        [
          {
            "service_name": "api",
            "image": "myapp/api:latest",
            "port": 8080,
            "domain": "api",
            "replicas": 2,
            "use_secrets": true,
            "secrets": [
              "cloudflare-api-token",
              "jwt-secret"
            ],
            "environment": {
              "NODE_ENV": "production",
              "DATABASE_URL": "postgres://db:5432/myapp"
            }
          }
        ]
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Advanced Secrets Configuration

```yaml
name: Deploy with Advanced Secrets

on:
  workflow_dispatch:

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'complex-app'
      environment_type: 'prod'
      services_config: |
        [
          {
            "service_name": "api",
            "image": "myapp/api:${{ github.sha }}",
            "port": 8080,
            "domain": "api",
            "replicas": 3,
            "use_secrets": true,
            "secrets": [
              "api-key",
              {
                "source": "ssl-cert",
                "target": "/etc/ssl/certs/server.crt",
                "mode": "0444"
              },
              {
                "source": "ssl-key",
                "target": "/etc/ssl/private/server.key",
                "mode": "0400",
                "uid": "1000",
                "gid": "1000"
              }
            ],
            "environment": {
              "NODE_ENV": "production",
              "LOG_LEVEL": "info"
            },
            "health_url": "/health",
            "enable_retry": true,
            "enable_rate_limit": true
          },
          {
            "service_name": "database",
            "image": "postgres:15",
            "port": 5432,
            "expose": false,
            "secrets": [
              {
                "source": "postgres-password",
                "target": "/run/secrets/db_password",
                "uid": "999",
                "gid": "999"
              }
            ],
            "environment": {
              "POSTGRES_DB": "myapp",
              "POSTGRES_USER": "admin",
              "POSTGRES_PASSWORD_FILE": "/run/secrets/db_password"
            },
            "volumes": [
              {
                "name": "postgres_data",
                "path": "/var/lib/postgresql/data"
              }
            ],
            "networks": ["backend", "database"]
          }
        ]
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Automatic Secret Detection

When `use_secrets: true` is set, sensitive environment variables are automatically converted to secrets:

```yaml
services_config: |
  [
    {
      "service_name": "api",
      "image": "myapp/api:latest",
      "port": 8080,
      "domain": "api",
      "use_secrets": true,
      "env": "prod",
      "environment": {
        "NODE_ENV": "production",
        "API_KEY": "${{ secrets.API_KEY }}",
        "DATABASE_PASSWORD": "${{ secrets.DB_PASSWORD }}"
      }
    }
  ]
```

This will automatically:

1. Create Docker secrets for `API_KEY` and `DATABASE_PASSWORD`
2. Mount them as files in the container
3. Set environment variables `API_KEY_FILE` and `DATABASE_PASSWORD_FILE` pointing to the secret files

## Multi-Service with Mixed Secrets

```yaml
services_config: |
  [
    {
      "service_name": "frontend",
      "image": "myapp/frontend:latest",
      "port": 3000,
      "domain": "app",
      "secrets": ["ssl-cert", "ssl-key"],
      "environment": {
        "REACT_APP_API_URL": "https://api.example.com"
      }
    },
    {
      "service_name": "api",
      "image": "myapp/api:latest",
      "port": 8080,
      "domain": "api",
      "use_secrets": true,
      "secrets": [
        "jwt-secret",
        {
          "source": "api-config",
          "target": "/etc/api/config.json",
          "mode": "0400"
        }
      ],
      "environment": {
        "DATABASE_PASSWORD": "${{ secrets.DB_PASSWORD }}",
        "REDIS_PASSWORD": "${{ secrets.REDIS_PASSWORD }}"
      }
    },
    {
      "service_name": "worker",
      "image": "myapp/worker:latest",
      "expose": false,
      "secrets": ["redis-password", "api-key"],
      "environment": {
        "WORKER_CONCURRENCY": "5"
      }
    }
  ]
```

## Creating External Secrets

Before deployment, create the required Docker secrets:

```bash
# Create secrets from files
echo "your-api-key" | docker secret create api-key -
echo "your-jwt-secret" | docker secret create jwt-secret -

# Create from files
docker secret create ssl-cert ./cert.pem
docker secret create ssl-key ./key.pem

# Create with specific content
printf "your-password" | docker secret create postgres-password -
```

## Best Practices

1. **Secret Naming**: Use descriptive, lowercase names with hyphens (e.g., `api-key`, `db-password`)

2. **Permissions**: Set appropriate file permissions:
   - `0400` (read-only by owner) for most secrets
   - `0444` (read-only by all) for public certificates
   - Set `uid`/`gid` to match the container's user

3. **Environment Variables**:
   - Use `_FILE` suffix for env vars that read from secret files
   - Example: `DATABASE_PASSWORD_FILE=/run/secrets/db_password`

4. **Secret Rotation**: Plan for secret rotation without service interruption

5. **Validation**: Always verify secrets are created before deployment:

   ```bash
   docker secret ls
   ```

## Troubleshooting

### Secret Not Found

```text
service api: secret not found: api-key
```

**Solution**: Create the secret before deployment:

```bash
echo "your-secret" | docker secret create api-key -
```

### Permission Denied

```text
Error: Permission denied reading /run/secrets/api_key
```

**Solution**: Check the secret's mode, uid, and gid match the container's user

### Environment Variable Not Set

```text
Error: DATABASE_PASSWORD_FILE environment variable not found
```

**Solution**: Ensure you're using the `_FILE` suffix and the secret is properly mounted

## Complete Example

Here's a production-ready example combining all features:

```yaml
name: Production Deployment

on:
  push:
    branches: [main]

jobs:
  create-secrets:
    runs-on: ubuntu-latest
    steps:
      - name: Create Docker secrets
        run: |
          # This is just an example - in real scenarios, 
          # secrets should be pre-created on the Swarm cluster
          echo "Secrets should be created on the target Swarm cluster"

  deploy:
    needs: create-secrets
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'production-app'
      environment_type: 'prod'
      services_config: |
        [
          {
            "service_name": "nginx",
            "image": "nginx:alpine",
            "port": 80,
            "domain": "www",
            "replicas": 2,
            "secrets": [
              {
                "source": "ssl-cert",
                "target": "/etc/nginx/ssl/cert.pem",
                "mode": "0444"
              },
              {
                "source": "ssl-key", 
                "target": "/etc/nginx/ssl/key.pem",
                "mode": "0400"
              }
            ],
            "volumes": [
              {
                "name": "nginx-config",
                "path": "/etc/nginx/conf.d",
                "driver": "local"
              }
            ]
          },
          {
            "service_name": "api",
            "image": "myapp/api:${{ github.sha }}",
            "port": 8080,
            "domain": "api",
            "replicas": 3,
            "use_secrets": true,
            "secrets": [
              "cloudflare-api-token",
              "jwt-signing-key",
              {
                "source": "database-ca-cert",
                "target": "/etc/ssl/certs/db-ca.pem",
                "mode": "0444"
              }
            ],
            "environment": {
              "NODE_ENV": "production",
              "DATABASE_PASSWORD": "${{ secrets.DB_PASSWORD }}",
              "REDIS_PASSWORD": "${{ secrets.REDIS_PASSWORD }}",
              "JWT_SECRET": "${{ secrets.JWT_SECRET }}"
            },
            "health_url": "/api/health",
            "enable_retry": true,
            "enable_rate_limit": true,
            "rate_limit": {
              "average": 100,
              "burst": 50
            },
            "resources": {
              "limits": {
                "cpus": "2.0",
                "memory": "2G"
              }
            }
          },
          {
            "service_name": "postgres",
            "image": "postgres:15-alpine",
            "port": 5432,
            "expose": false,
            "replicas": 1,
            "secrets": [
              {
                "source": "postgres-password",
                "target": "/run/secrets/postgres_password",
                "uid": "70",
                "gid": "70"
              },
              {
                "source": "postgres-replication-password",
                "target": "/run/secrets/replication_password",
                "uid": "70",
                "gid": "70"
              }
            ],
            "environment": {
              "POSTGRES_DB": "production",
              "POSTGRES_USER": "admin",
              "POSTGRES_PASSWORD_FILE": "/run/secrets/postgres_password",
              "POSTGRES_INITDB_ARGS": "--auth-host=scram-sha-256"
            },
            "volumes": [
              {
                "name": "postgres_data",
                "path": "/var/lib/postgresql/data",
                "driver": "local",
                "backup": "true"
              }
            ],
            "networks": ["database"],
            "constraints": ["node.labels.storage == ssd"],
            "health_check": {
              "test": ["CMD-SHELL", "pg_isready -U admin"],
              "interval": "10s",
              "timeout": "5s",
              "retries": 5,
              "start_period": "30s"
            }
          }
        ]
      pre_deploy_commands: |
        [
          "echo 'Verifying secrets are created...'",
          "docker secret ls | grep -E 'ssl-cert|ssl-key|jwt-signing-key|postgres-password' || echo 'Warning: Some secrets may be missing'"
        ]
      post_deploy_commands: |
        [
          "echo 'Deployment complete'",
          "echo 'Services deployed with secrets protection'"
        ]
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

This example demonstrates:

- SSL certificate secrets for nginx
- Automatic secret conversion for sensitive environment variables
- Custom permissions for PostgreSQL secrets
- Mixed secret formats (simple strings and detailed configs)
- Pre-deployment validation of secrets
- Complete production configuration with health checks, resource limits, and constraints
