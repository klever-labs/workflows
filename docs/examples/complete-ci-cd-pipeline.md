# Complete CI/CD Pipeline Example

This example shows how to combine multiple workflows for a complete CI/CD pipeline.

## Example: Full Pipeline for a Node.js Application

This workflow:

1. Runs CI checks on every push
2. Builds Docker image on main/develop branches
3. Automatically deploys to the appropriate environment

```yaml
name: Complete CI/CD Pipeline

on:
  push:
    branches: [main, develop, feature/*]
  pull_request:
    branches: [main, develop]

env:
  REGISTRY: gcr.io
  PROJECT_ID: my-project-123
  APP_NAME: my-nodejs-app

jobs:
  # Step 1: Run CI checks
  ci:
    name: CI Checks
    uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
    with:
      node-version: '20.x'
      pnpm-version: '8'
      run-build: true
      run-tests: true

  # Step 2: Build Docker image (only on main/develop)
  docker-build:
    name: Build Docker Image
    needs: ci
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: gcr.io
      flavor: javascript
      extra_build_args: |
        NODE_ENV=production
        BUILD_DATE=${{ github.event.head_commit.timestamp }}
        COMMIT_SHA=${{ github.sha }}
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
      gcp_cloud_run_sa: ${{ secrets.GCP_SA }}
      gcp_project_id: ${{ secrets.GCP_PROJECT_ID }}

  # Step 3: Deploy to appropriate environment
  deploy:
    name: Deploy Application
    needs: docker-build
    uses: klever-labs/workflows/.github/workflows/deploy-swarm.yml@main
    with:
      repository_name: ${{ env.APP_NAME }}
      service_names: 'api,worker'
      image_urls: |
        {
          "api": "${{ needs.docker-build.outputs.image }}",
          "worker": "${{ needs.docker-build.outputs.image }}"
        }
      domains_prefix: 'api,worker'
      fqdn: ${{ github.ref == 'refs/heads/main' && 'prod.example.com' || 'dev.example.com' }}
      server_ports: '8080,9090'
      environment_type: ${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
      
      # Production gets more replicas and resource limits
      replica_count: ${{ github.ref == 'refs/heads/main' && '3' || '1' }}
      resource_limits: ${{ github.ref == 'refs/heads/main' }}
      
      # Health checks for all environments
      health_checks: true
      health_urls: '/health,/health'
      
      # Environment-specific configuration
      service_envs: |
        {
          "api": {
            "NODE_ENV": "${{ github.ref == 'refs/heads/main' && 'production' || 'development' }}",
            "LOG_LEVEL": "${{ github.ref == 'refs/heads/main' && 'info' || 'debug' }}",
            "API_VERSION": "v1",
            "WORKER_URL": "http://worker:9090"
          },
          "worker": {
            "NODE_ENV": "${{ github.ref == 'refs/heads/main' && 'production' || 'development' }}",
            "CONCURRENCY": "${{ github.ref == 'refs/heads/main' && '10' || '2' }}",
            "QUEUE_NAME": "jobs"
          }
        }
      
      # Pre/post deployment hooks
      pre_deploy_commands: |
        [
          "echo 'Starting deployment for commit ${{ github.sha }}'",
          "echo 'Environment: ${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}'"
        ]
      post_deploy_commands: |
        [
          "echo 'Deployment completed successfully'",
          "curl -X POST https://api.statuspage.io/v1/incidents -d '{\"status\":\"resolved\"}'"
        ]
    secrets:
      portainer_url: ${{ secrets.PORTAINER_URL }}
      portainer_api_token: ${{ secrets.PORTAINER_API_TOKEN }}
      twingate_sa: ${{ secrets.TWINGATE_SERVICE_ACCOUNT }}

  # Step 4: Notification on completion
  notify:
    name: Send Notifications
    needs: [ci, docker-build, deploy]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Slack Notification
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            Pipeline Status: ${{ needs.deploy.result }}
            Environment: ${{ github.ref == 'refs/heads/main' && 'Production' || 'Development' }}
            Commit: ${{ github.sha }}
            Author: ${{ github.actor }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## Separate Workflows Approach

For better organization, you might want to split this into separate workflow files:

### `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main, develop, feature/*]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
    with:
      node-version: '20.x'
      pnpm-version: '8'
```

### `.github/workflows/deploy.yml`

```yaml
name: Deploy

on:
  workflow_run:
    workflows: ["CI"]
    types:
      - completed
    branches: [main, develop]

jobs:
  build-and-deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    # ... rest of the build and deploy jobs
```

## Required Secrets

Make sure to set up these secrets in your repository:

1. **GCP Secrets** (for Google Container Registry):
   - `GCP_SA`: Service account JSON
   - `GCP_PROJECT_ID`: GCP project ID

2. **Portainer Secrets**:
   - `PORTAINER_URL`: Your Portainer instance URL
   - `PORTAINER_API_TOKEN`: API token for authentication

3. **Optional Secrets**:
   - `TWINGATE_SERVICE_ACCOUNT`: For private network access
   - `SLACK_WEBHOOK`: For notifications

## Environment-Specific Configurations

The example above shows how to:

- Deploy to different domains based on branch
- Use different replica counts for prod vs dev
- Apply resource limits only in production
- Set environment-specific variables
- Run different pre/post deployment commands

## Monitoring and Rollback

The pipeline includes:

- Smoke tests after deployment
- Deployment reports in GitHub Actions summary
- Artifact retention for rollback scenarios
- Automatic rollback on failure

## Best Practices Demonstrated

1. **Conditional execution**: Only build/deploy from specific branches
2. **Environment detection**: Automatic environment selection based on branch
3. **Resource optimization**: Different settings for prod vs dev
4. **Health checks**: Ensure services are healthy after deployment
5. **Notifications**: Keep team informed of deployment status
6. **Artifact management**: Keep deployment artifacts for debugging/rollback
