# Deploy to Docker Swarm Examples

This document provides examples of using the modular deployment workflows for Docker Swarm via Portainer.

## Table of Contents

- [Overview](#overview)
- [Basic Usage](#basic-usage)
- [Using Pre-built Compose Files](#using-pre-built-compose-files)
- [Deploy After Docker Build](#deploy-after-docker-build)
- [Multi-Service Deployment](#multi-service-deployment)
- [Environment-Specific Deployments](#environment-specific-deployments)
- [Advanced Configuration](#advanced-configuration)
- [Using Modular Workflows Directly](#using-modular-workflows-directly)
- [Troubleshooting](#troubleshooting)

## Overview

The deployment system consists of three workflows:

1. **`deploy-swarm.yml`** - High-level orchestrator (simplified interface)
2. **`generate-compose.yml`** - Generates Docker Compose files from JSON config
3. **`deploy-compose.yml`** - Deploys compose files to Docker Swarm

You can use either the simplified `deploy-swarm.yml` or combine the modular workflows for more control.

## Basic Usage

### Simple single-service deployment

```yaml
name: Deploy Application

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'my-app'
      services_config: |
        [
          {
            "service_name": "my-app",
            "image": "gcr.io/my-project/my-app:latest",
            "port": 3000,
            "domain": "my-app",
            "replicas": 2
          }
        ]
      environment_type: 'prod'
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Using Pre-built Compose Files

If you already have a docker-compose.yml file:

```yaml
name: Deploy with Existing Compose

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'my-app'
      compose_file: 'docker/compose.prod.yml'  # Path to your compose file
      environment_type: 'prod'
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Deploy After Docker Build

### Automated deployment after successful image build

```yaml
name: Build and Deploy

on:
  push:
    branches: [main, develop]

jobs:
  build:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: gcr.io
      flavor: javascript
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
      gcp_cloud_run_sa: ${{ secrets.GCP_SA }}
      gcp_project_id: ${{ secrets.GCP_PROJECT_ID }}

  deploy:
    needs: build
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'my-app'
      services_config: |
        [
          {
            "service_name": "my-app",
            "image": "${{ needs.build.outputs.image }}",
            "port": 8080,
            "domain": "app",
            "replicas": ${{ github.ref == 'refs/heads/main' && '3' || '1' }},
            "health_url": "/health",
            "enable_retry": true
          }
        ]
      environment_type: ${{ github.ref == 'refs/heads/main' && 'prod' || 'staging' }}
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Multi-Service Deployment

### Deploy multiple services with different configurations

```yaml
name: Deploy Microservices

on:
  workflow_dispatch:

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'my-platform'
      services_config: |
        [
          {
            "service_name": "api",
            "image": "gcr.io/my-project/api:v1.2.3",
            "port": 3000,
            "domain": "api",
            "replicas": 2,
            "environment": {
              "DATABASE_URL": "postgres://...",
              "REDIS_URL": "redis://..."
            },
            "health_url": "/health",
            "enable_retry": true,
            "enable_rate_limit": true
          },
          {
            "service_name": "frontend",
            "image": "gcr.io/my-project/frontend:v2.0.0",
            "port": 8080,
            "domain": "app",
            "replicas": 3,
            "health_url": "/",
            "resources": {
              "limits": { "cpus": "1.0", "memory": "1G" }
            }
          },
          {
            "service_name": "worker",
            "image": "gcr.io/my-project/worker:v1.0.5",
            "expose": false,
            "replicas": 2,
            "environment": {
              "QUEUE_NAME": "jobs",
              "CONCURRENCY": "5"
            },
            "health_url": "/status",
            "resources": {
              "limits": { "cpus": "2.0", "memory": "2G" }
            }
          }
        ]
      environment_type: 'prod'
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Environment-Specific Deployments

### Deploy based on branch with environment detection

```yaml
name: Deploy on Push

on:
  push:
    branches: [main, develop, staging]

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'my-app'
      services_config: |
        [
          {
            "service_name": "my-app",
            "image": "gcr.io/my-project/my-app:${{ github.sha }}",
            "port": 3000,
            "domain": "app",
            "replicas": ${{ github.ref == 'refs/heads/main' && '3' || '1' }},
            "env": "${{ github.ref == 'refs/heads/main' && 'prod' || github.ref == 'refs/heads/develop' && 'dev' || 'staging' }}",
            "resource_limits": ${{ github.ref == 'refs/heads/main' }},
            "health_checks": true,
            "enable_retry": ${{ github.ref == 'refs/heads/main' }},
            "enable_rate_limit": ${{ github.ref == 'refs/heads/main' }},
            "environment": {
              "NODE_ENV": "${{ github.ref == 'refs/heads/main' && 'production' || 'development' }}",
              "LOG_LEVEL": "${{ github.ref == 'refs/heads/main' && 'error' || 'debug' }}"
            }
          }
        ]
      environment_type: |
        ${{ 
          github.ref == 'refs/heads/main' && 'prod' ||
          github.ref == 'refs/heads/develop' && 'dev' ||
          github.ref == 'refs/heads/staging' && 'staging' ||
          'dev'
        }}
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Advanced Configuration

### Full-featured deployment with all options

```yaml
name: Advanced Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'complex-app'
      service_names: 'api,frontend,redis,postgres'
      image_urls: |
        {
          "api": "gcr.io/my-project/api:${{ github.sha }}",
          "frontend": "gcr.io/my-project/frontend:${{ github.sha }}",
          "redis": "redis:7-alpine",
          "postgres": "postgres:15-alpine"
        }
      domains_prefix: 'api,app'
      fqdn: 'myapp.io'
      server_ports: '8080,3000,6379,5432'
      environment_type: ${{ inputs.environment }}
      replica_count: '2'
      
      # Resource management
      resource_limits: true
      volume_persistence: true
      volume_dir: '/var/lib/app-data'
      
      # Health checks
      health_checks: true
      health_urls: '/health,/,/ping,/ready'
      
      # Environment variables
      service_envs: |
        {
          "api": {
            "NODE_ENV": "${{ inputs.environment }}",
            "LOG_LEVEL": "info",
            "DATABASE_HOST": "postgres",
            "REDIS_HOST": "redis"
          },
          "frontend": {
            "REACT_APP_API_URL": "https://api-${{ inputs.environment }}.myapp.io"
          },
          "postgres": {
            "POSTGRES_DB": "myapp",
            "POSTGRES_USER": "appuser"
          }
        }
      
      # Secrets configuration
      use_secrets: true
      service_secrets: |
        {
          "api": ["cloudflare-api-token", "jwt-secret"],
          "postgres": [
            {
              "source": "postgres-password",
              "target": "/run/secrets/db_password"
            }
          ]
        }
      
      # Deployment configuration
      deployment_strategy: 'rolling'
      prune_services: true
      
      # Custom commands
      pre_deploy_commands: |
        [
          "echo 'Starting deployment to ${{ inputs.environment }}'",
          "date"
        ]
      post_deploy_commands: |
        [
          "echo 'Deployment completed'",
          "curl -X POST https://api.monitoring.com/deployment -d '{\"env\":\"${{ inputs.environment }}\"}''"
        ]
      
      # Portainer configuration
      portainer_endpoint_id: '2'
      portainer_swarm_id: 'custom-swarm-id'
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
      twingate_sa: ${{ secrets.TWINGATE_SERVICE_ACCOUNT }}
```

### Deployment with Docker Swarm Secrets

```yaml
name: Deploy with Secrets

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'secure-app'
      service_names: 'api,worker,database'
      image_urls: |
        {
          "api": "gcr.io/my-project/api:${{ github.sha }}",
          "worker": "gcr.io/my-project/worker:${{ github.sha }}",
          "database": "postgres:15"
        }
      domains_prefix: 'api'
      fqdn: 'secure.example.com'
      server_ports: '8080'
      environment_type: 'prod'
      
      # Enable secrets management
      use_secrets: true
      
      # Map secrets to services
      service_secrets: |
        {
          "api": [
            "api-key",
            "jwt-secret",
            {
              "source": "ssl-cert",
              "target": "/etc/ssl/certs/server.crt",
              "mode": "0444"
            },
            {
              "source": "ssl-key",
              "target": "/etc/ssl/private/server.key",
              "mode": "0400"
            }
          ],
          "worker": ["redis-password", "api-key"],
          "database": [
            {
              "source": "postgres-password",
              "target": "/run/secrets/postgres_password",
              "uid": "999",
              "gid": "999"
            }
          ]
        }
      
      # Environment variables (sensitive ones will auto-convert to secrets)
      service_envs: |
        {
          "api": {
            "DATABASE_PASSWORD": "${{ secrets.DB_PASSWORD }}",
            "JWT_SECRET": "${{ secrets.JWT_SECRET }}"
          },
          "database": {
            "POSTGRES_PASSWORD_FILE": "/run/secrets/postgres_password"
          }
        }
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

### Using with workflow_run trigger

```yaml
name: Deploy After Release

on:
  workflow_run:
    workflows: ["Create Release"]
    types:
      - completed
    branches: [main]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: 'my-app'
      services_config: |
        [
          {
            "service_name": "my-app",
            "image": "gcr.io/my-project/my-app:${{ github.event.workflow_run.head_sha }}",
            "port": 443,
            "domain": "app",
            "replicas": 3,
            "resource_limits": true,
            "health_checks": true,
            "enable_monitoring": true
          }
        ]
      environment_type: 'prod'
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Using Modular Workflows Directly

For more control, you can use the modular workflows separately:

### Generate and Deploy Separately

```yaml
name: Custom Deployment Pipeline

on:
  workflow_dispatch:

jobs:
  generate:
    uses: klever-labs/workflows/.github/workflows/generate-compose.yml@main
    with:
      services_config: |
        [
          {
            "service_name": "api",
            "image": "myapp/api:latest",
            "port": 8080,
            "domain": "api",
            "replicas": 2,
            "secrets": ["api-key", "db-password"]
          }
        ]
      environment_type: 'prod'
      artifact_name: 'compose-custom'

  validate:
    needs: generate
    runs-on: ubuntu-latest
    steps:
      - name: Download compose artifact
        uses: actions/download-artifact@v4
        with:
          name: compose-custom
          
      - name: Validate compose file
        run: |
          cat docker-compose.yml
          docker compose config

  deploy:
    needs: [generate, validate]
    uses: klever-labs/workflows/.github/workflows/deploy-compose.yml@main
    with:
      stack_name: 'my-app-prod'
      compose_artifact: 'compose-custom'
      environment_type: 'prod'
      pre_deploy_commands: |
        [
          "echo 'Running pre-deployment checks'",
          "date"
        ]
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

### Direct Compose Deployment

If you manage your own compose files:

```yaml
name: Deploy Custom Compose

on:
  push:
    paths:
      - 'docker-compose.prod.yml'
    branches: [main]

jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy-compose.yml@main
    with:
      stack_name: 'production-stack'
      compose_file: 'docker-compose.prod.yml'
      environment_type: 'prod'
      prune_services: true
      post_deploy_commands: |
        [
          "echo 'Stack deployed successfully'",
          "curl -X POST https://monitoring.example.com/deploy-event"
        ]
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
```

## Troubleshooting

### Common Issues

1. **Stack creation fails**
   - Verify Portainer credentials are correct
   - Check if the Portainer endpoint ID is valid
   - Ensure Twingate is connected (if using private networks)

2. **Image not found**
   - Verify the image URL is correct and accessible
   - Check registry authentication
   - Ensure the image was pushed successfully

3. **Service not accessible**
   - Check if the domain is correctly configured
   - Verify the port mapping is correct
   - Check health check configuration

4. **Environment variables not working**
   - Ensure the JSON format is valid in `service_envs`
   - Check for special characters that need escaping
   - Verify variable names match what the application expects

5. **Secrets not available in containers**
   - Ensure external secrets are created before deployment: `docker secret create <name> <file>`
   - Verify the secret names match exactly (case-sensitive)
   - Check secret permissions (mode, uid, gid) match container requirements
   - For sensitive env vars with `use_secrets: true`, look for `_FILE` suffix variables

### Debug Mode

Enable detailed logging by adding these to your workflow:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
```

### Rollback Strategy

The workflow includes automatic rollback on failure. To manually rollback:

1. Check the artifacts for previous compose files
2. Re-run the workflow with a known good image tag
3. Or restore from Portainer's stack backup

## Best Practices

1. **Use immutable tags**: Prefer SHA-based tags over `latest`
2. **Test in staging**: Always deploy to staging before production
3. **Monitor deployments**: Use the smoke tests and health checks
4. **Resource limits**: Set appropriate limits to prevent resource exhaustion
5. **Secret management**:
   - Never hardcode secrets; use GitHub Secrets for workflow secrets
   - Use Docker Swarm secrets for runtime secrets with `service_secrets`
   - Enable `use_secrets: true` in production to auto-convert sensitive env vars
   - Create external secrets before deployment: `docker secret create <name> <file>`
   - Set appropriate permissions (mode, uid, gid) for secret files
6. **Backup strategy**: Keep compose file artifacts for rollback
7. **Health checks**: Always configure health checks for production
8. **Gradual rollout**: Use replica_count to control rollout speed
