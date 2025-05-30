# Docker Build Workflow Examples

This document provides examples of using the `docker-build.yml` reusable workflow for building and
pushing Docker images to various container registries.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Google Container Registry (GCR)](#google-container-registry-gcr)
- [GitHub Container Registry (GHCR)](#github-container-registry-ghcr)
- [Docker Hub](#docker-hub)
- [Configuration Files](#configuration-files)
- [Advanced Options](#advanced-options)
- [Multi-Platform Builds](#multi-platform-builds)
- [Caching Strategies](#caching-strategies)

## Basic Usage

### Simple Docker build for a Go application

```yaml
name: Build and Push

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      flavor: golang
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

## Google Container Registry (GCR)

### Full GCR setup with environment-specific tags

```yaml
name: Build for GCR

on:
  push:
    branches: [main, develop]

jobs:
  build-staging:
    if: github.ref == 'refs/heads/develop'
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      environment: staging
      registry_name: gcr.io
      flavor: golang
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
      gcp_cloud_run_sa: ${{ secrets.GCP_SA_STAGING }}
      gcp_project_id: ${{ secrets.GCP_PROJECT_STAGING }}

  build-production:
    if: github.ref == 'refs/heads/main'
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      environment: production
      registry_name: gcr.io
      flavor: golang
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
      gcp_cloud_run_sa: ${{ secrets.GCP_SA_PROD }}
      gcp_project_id: ${{ secrets.GCP_PROJECT_PROD }}
```

## GitHub Container Registry (GHCR)

### Build and push to GitHub Container Registry

```yaml
name: Build for GHCR

on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: nodejs
      runs_on: ubuntu-latest
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

## Docker Hub

### Build and push to Docker Hub

```yaml
name: Build for Docker Hub

on:
  push:
    tags:
      - 'v*'

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: docker.io
      flavor: python
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
      registry_user: ${{ secrets.DOCKERHUB_USERNAME }}
      registry_pass: ${{ secrets.DOCKERHUB_TOKEN }}
```

## Configuration Files

### Using shared configuration files (nginx.conf, etc.)

```yaml
name: JavaScript App with Nginx Config

on:
  push:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: javascript
      download_configs: true  # Downloads nginx.conf and other config files
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

### Disable config download for custom configs

```yaml
name: Custom Config Files

on:
  push:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: javascript
      download_configs: false  # Use project's own config files
      use_default_dockerfiles: true
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

## Advanced Options

### Custom Dockerfile with pre-build step

```yaml
name: Custom Build

on:
  push:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: custom
      dockerfile_path: docker/Dockerfile.production
      context_path: .
      build_dir: dist
      pre_build: true
      use_default_dockerfiles: false
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

### JavaScript/Node.js with build secrets

```yaml
name: Node.js App with Secrets

on:
  push:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: gcr.io
      flavor: javascript
      build_dir: build
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
      build_secrets: |
        API_URL=${{ secrets.API_URL }}
        API_KEY=${{ secrets.API_KEY }}
        NODE_ENV=production
      gcp_cloud_run_sa: ${{ secrets.GCP_SA }}
      gcp_project_id: ${{ secrets.GCP_PROJECT }}
```

### Custom build arguments

```yaml
name: Build with Custom Args

on:
  push:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: golang
      extra_build_args: |
        GOPROXY=https://proxy.golang.org
        GOSUMDB=sum.golang.org
        CGO_ENABLED=0
        CUSTOM_FLAG=true
        VERSION=${{ github.ref_name }}
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

## Multi-Platform Builds

### Build for multiple architectures

```yaml
name: Multi-Platform Build

on:
  push:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: golang
      platforms: linux/amd64,linux/arm64
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

## Caching Strategies

### Advanced caching with BuildKit

```yaml
name: Build with Cache

on:
  push:
    branches: [main]

jobs:
  docker:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: golang
      cache_from: |
        type=gha
        type=registry,ref=ghcr.io/${{ github.repository }}:buildcache
      cache_to: |
        type=gha,mode=max
        type=registry,ref=ghcr.io/${{ github.repository }}:buildcache,mode=max
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

## Using Workflow Outputs

### Deploy after build using workflow outputs

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

jobs:
  build:
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: gcr.io
      flavor: golang
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
      gcp_cloud_run_sa: ${{ secrets.GCP_SA }}
      gcp_project_id: ${{ secrets.GCP_PROJECT }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Cloud Run
        run: |
          echo "Deploying image: ${{ needs.build.outputs.image }}"
          echo "Image tags: ${{ needs.build.outputs.tags }}"
          # Add your deployment commands here
```

## Matrix Builds

### Build multiple flavors in parallel

```yaml
name: Matrix Docker Build

on:
  push:
    branches: [main]

jobs:
  docker:
    strategy:
      matrix:
        include:
          - service: api
            flavor: golang
            dockerfile: Dockerfile.api
          - service: frontend
            flavor: javascript
            dockerfile: Dockerfile.frontend
          - service: worker
            flavor: python
            dockerfile: Dockerfile.worker
    uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
    with:
      registry_name: ghcr.io
      flavor: ${{ matrix.flavor }}
      dockerfile_path: ${{ matrix.dockerfile }}
      additional_tags: ${{ matrix.service }}-latest
    secrets:
      git_pass: ${{ secrets.GITHUB_TOKEN }}
```

## Troubleshooting

### Common Issues

1. **GCR Authentication Failures**
   - Ensure the service account JSON is properly formatted
   - Verify the service account has necessary permissions
   - Check that the project ID is correct

2. **Build Secrets Not Available**
   - Ensure secrets are properly escaped in YAML
   - Use pipe (`|`) for multi-line secrets
   - Verify secret names match exactly

3. **Cache Not Working**
   - Ensure cache keys are unique per build
   - Check that cache paths are correct
   - Verify runner has sufficient disk space

### Debug Mode

Enable debug output by adding:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  BUILDKIT_PROGRESS: plain
```

## Best Practices

1. **Use specific tags**: Always tag images with SHA and environment
2. **Enable scanning**: Use Trivy scanning for production builds
3. **Optimize layers**: Order Dockerfile commands from least to most frequently changing
4. **Use build cache**: Leverage GitHub Actions cache for faster builds
5. **Multi-stage builds**: Use multi-stage Dockerfiles to reduce final image size
6. **Secret management**: Never hardcode secrets; always use GitHub Secrets
7. **Version pinning**: Pin base images and dependencies for reproducible builds
8. **Build arguments**: Use `extra_build_args` for dynamic configuration without modifying Dockerfiles
9. **ARG security**: Never pass secrets as build args; they're visible in image history
