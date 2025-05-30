# Workflow Conventions

This document outlines the conventions and best practices for creating and maintaining workflows in this repository.

## Naming Conventions

### Workflow Files

- Use kebab-case: `deploy-app.yml`, `run-tests.yml`
- Be descriptive but concise
- Include technology prefix when specific: `node-build.yml`, `python-test.yml`
- Environment-specific workflows: `deploy-staging.yml`, `deploy-production.yml`

### Job Names

```yaml
jobs:
  build-application:    # Descriptive, kebab-case
    name: Build Application  # Human-readable display name
```

### Step Names

```yaml
steps:
  - name: Checkout code
  - name: Setup Node.js environment
  - name: Install dependencies
  - name: Run tests with coverage
```

## Workflow Structure

### Standard Structure

```yaml
name: Workflow Name
# Brief description of what this workflow does

on:
  workflow_call:  # For reusable workflows
    inputs:
      # Define all inputs with descriptions
    secrets:
      # Define required secrets
      
permissions:
  contents: read  # Minimal required permissions

jobs:
  job-name:
    runs-on: ubuntu-latest
    steps:
      # Workflow steps
```

### Input Definitions

Always provide clear descriptions and defaults where appropriate:

```yaml
inputs:
  node-version:
    description: 'Node.js version to use'
    required: false
    default: '18'
    type: string
    
  environment:
    description: 'Deployment environment (staging/production)'
    required: true
    type: string
```

## Security Best Practices

### Action Pinning

Always pin third-party actions to a specific commit SHA:

```yaml
# Good - pinned to specific commit
uses: actions/setup-node@8f152de45cc393bb48ce5d89d36b731f54556e65  # v4.0.0

# Acceptable for official actions
uses: actions/checkout@v4

# Bad - using branch reference for third-party
uses: some-org/some-action@main
```

### Permissions

Use minimal required permissions:

```yaml
permissions:
  contents: read
  packages: write
  # Explicitly set to none if not needed
  issues: none
  pull-requests: none
```

### Secrets Handling

```yaml
# Never hardcode secrets
env:
  API_KEY: ${{ secrets.API_KEY }}
  
# Use GitHub's built-in masking
- name: Display masked value
  run: echo "::add-mask::${{ secrets.SECRET_VALUE }}"
```

## Reusability Guidelines

### Making Workflows Reusable

1. Use `workflow_call` trigger
2. Define clear inputs and outputs
3. Document requirements in comments
4. Provide sensible defaults

```yaml
on:
  workflow_call:
    inputs:
      config-file:
        description: 'Path to configuration file'
        default: '.github/config.yml'
        type: string
    outputs:
      artifact-name:
        description: 'Name of the built artifact'
        value: ${{ jobs.build.outputs.artifact }}
```

### Composite Actions

For smaller reusable components, create composite actions:

```yaml
# actions/setup-environment/action.yml
name: 'Setup Environment'
description: 'Setup common environment variables and tools'
inputs:
  node-version:
    description: 'Node.js version'
    default: '18'
runs:
  using: 'composite'
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
```

## Documentation Standards

### Inline Documentation

```yaml
# Deploy Application Workflow
# 
# This workflow handles deployment to AWS ECS
# Required secrets:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
# Required inputs:
#   - environment: target environment (staging/production)
#   - service-name: ECS service name
```

### README for Complex Workflows

For complex workflows, create a README in the same directory:
- `workflows/deploy-ecs.yml`
- `workflows/deploy-ecs.md`

## Testing Guidelines

### Local Testing

Use tools like `act` to test workflows locally:

```bash
# Test push event
act push

# Test with specific job
act -j build

# Test with secrets
act -s MY_SECRET=value
```

### Validation

Before committing:
1. Run `actionlint` for syntax validation
2. Run `yamllint` for YAML formatting
3. Test in a feature branch first

## Version Management

### Semantic Versioning

Tag stable versions of workflows:
- `v1.0.0` - Major version (breaking changes)
- `v1.1.0` - Minor version (new features)
- `v1.1.1` - Patch version (bug fixes)

### Branch Strategy

- `main` - Stable, production-ready workflows
- `develop` - Development versions
- `feature/*` - New workflow development

## Performance Optimization

### Caching

Use caching to improve performance:

```yaml
- name: Cache dependencies
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

### Parallel Jobs

Run independent jobs in parallel:

```yaml
jobs:
  test-unit:
    # Unit tests
  test-integration:
    # Integration tests
  lint:
    # Linting
  
  # This job waits for all others
  all-tests:
    needs: [test-unit, test-integration, lint]
```

## Maintenance

### Regular Updates

- Review and update action versions monthly
- Update deprecated features promptly
- Monitor GitHub's changelog for workflow updates

### Deprecation Process

1. Add deprecation notice in workflow
2. Notify users via PR/issue
3. Maintain deprecated version for 3 months
4. Remove after migration period