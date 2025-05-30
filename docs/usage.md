# Usage Guide

This guide provides detailed instructions on how to use the workflows in this repository.

## Table of Contents

- [Usage Guide](#usage-guide)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Basic Example](#basic-example)
  - [Using Reusable Workflows](#using-reusable-workflows)
    - [Workflow Inputs](#workflow-inputs)
    - [Passing Secrets](#passing-secrets)
  - [Using Technology-Specific Workflows](#using-technology-specific-workflows)
    - [Technology-Specific Example](#technology-specific-example)
  - [Using Composite Actions](#using-composite-actions)
    - [Basic Usage](#basic-usage)
    - [Using Official Actions](#using-official-actions)
  - [Common Patterns](#common-patterns)
    - [Multi-Environment Deployment](#multi-environment-deployment)
    - [Matrix Builds](#matrix-builds)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Debug Mode](#debug-mode)
    - [Support](#support)

## Getting Started

To use workflows from this repository, you need to reference them in your project's `.github/workflows` directory.

### Basic Example

```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]

jobs:
  build:
    uses: klever-labs/workflows/.github/workflows/build.yml@main
    with:
      language: node
      version: '18'
```

## Using Reusable Workflows

Reusable workflows are complete workflow definitions that can be called from other repositories.

### Workflow Inputs

Most workflows accept inputs for customization:

```yaml
jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy.yml@main
    with:
      environment: production
      aws-region: us-east-1
      service-name: my-app
```

### Passing Secrets

Secrets can be passed explicitly or inherited:

```yaml
jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy.yml@main
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    # Or use 'secrets: inherit' to pass all secrets
```

## Using Technology-Specific Workflows

Technology-specific workflows provide optimized configurations for different languages and frameworks.

### Technology-Specific Example

```yaml
name: Build and Deploy
on: push

jobs:
  build:
    uses: klever-labs/workflows/.github/workflows/node-build.yml@main
    with:
      node-version: '18'
      
  deploy:
    needs: build
    uses: klever-labs/workflows/.github/workflows/docker-deploy.yml@main
    with:
      image-name: my-app
      registry: ghcr.io
```

## Using Composite Actions

Composite actions are reusable units of steps that can be included in any workflow job.

### Basic Usage

```yaml
name: Build Project
on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js environment
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
```

### Using Official Actions

For Node.js setup, use the official GitHub action:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '18'        # Node.js version
    cache: 'npm'              # Package manager: npm, yarn, pnpm
    registry-url: 'https://npm.pkg.github.com'  # Optional registry
```

For pnpm setup, combine with pnpm's official action:

```yaml
- uses: pnpm/action-setup@v2
  with:
    version: '8'              # pnpm version
```

## Common Patterns

### Multi-Environment Deployment

```yaml
jobs:
  deploy-staging:
    uses: klever-labs/workflows/.github/workflows/deploy.yml@main
    with:
      environment: staging
      
  deploy-production:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    uses: klever-labs/workflows/.github/workflows/deploy.yml@main
    with:
      environment: production
```

### Matrix Builds

```yaml
jobs:
  test:
    strategy:
      matrix:
        node-version: ['16', '18', '20']
    uses: klever-labs/workflows/.github/workflows/test.yml@main
    with:
      node-version: ${{ matrix.node-version }}
```

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure your workflow has the necessary permissions:

   ```yaml
   permissions:
     contents: read
     packages: write
   ```

2. **Secret Not Found**: Make sure secrets are properly configured in your repository settings

3. **Workflow Not Found**: Verify the path and branch reference are correct

### Debug Mode

Enable debug logging by setting these secrets in your repository:

- `ACTIONS_STEP_DEBUG: true`
- `ACTIONS_RUNNER_DEBUG: true`

### Support

For issues or questions:

- Create an issue in this repository
- Contact the DevOps team at <devops@klever-labs.com>
