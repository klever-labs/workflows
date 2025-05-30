# Node.js CI with pnpm

This guide shows how to use the Node.js CI workflows for projects using pnpm.

## Available Workflows

### 1. node-ci.yml (Full Featured)

A comprehensive CI workflow with separate jobs for linting/type checking and code quality.

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  ci:
    uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
    with:
      node-version: '20.x'
      pnpm-version: '8'
```

#### Customization Options

```yaml
jobs:
  ci:
    uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
    with:
      node-version: '18.x'           # Node.js version
      pnpm-version: '8'              # pnpm version
      working-directory: './app'      # Monorepo support
      run-build: true                # Enable/disable build step
      run-tests: true                # Enable/disable tests
      lint-command: 'pnpm lint:all'  # Custom lint command
      typecheck-command: 'pnpm tsc'  # Custom typecheck command
      test-command: 'pnpm test:ci'   # Custom test command
      build-command: 'pnpm build:prod' # Custom build command
```

### 2. node-ci-simple.yml (Simplified)

A streamlined single-job workflow that runs all CI tasks sequentially.

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  ci:
    uses: klever-labs/workflows/.github/workflows/node-ci-simple.yml@main
    with:
      node-version: '20.x'
      pnpm-version: '8'
```

## Using the setup-pnpm Action

For custom workflows, use the `setup-pnpm` composite action:

```yaml
name: Custom Build
on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          
      - name: Setup pnpm with caching
        uses: klever-labs/workflows/actions/setup-pnpm@main
        with:
          version: '8'
          
      - name: Custom build steps
        run: |
          pnpm build
          pnpm test
```

## Required package.json Scripts

Your project should have these scripts defined:

```json
{
  "scripts": {
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "format:check": "prettier --check .",
    "test": "jest",
    "build": "your-build-command"
  }
}
```

## Migration from Existing Workflow

To migrate your existing workflow:

1. **Option 1: Direct Replacement**
   Replace your entire workflow file with:
   ```yaml
   name: CI
   on:
     push:
       branches: [main, develop]
     pull_request:
       branches: [main, develop]
   
   jobs:
     ci:
       uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
   ```

2. **Option 2: Gradual Migration**
   Keep your workflow but use the composite action:
   ```yaml
   steps:
     - uses: actions/checkout@v4
     - uses: actions/setup-node@v4
       with:
         node-version: '20.x'
     - uses: klever-labs/workflows/actions/setup-pnpm@main
       with:
         version: '8'
     # Your custom steps...
   ```

## Monorepo Support

For monorepos, specify the working directory:

```yaml
jobs:
  ci-frontend:
    uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
    with:
      working-directory: './packages/frontend'
      
  ci-backend:
    uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
    with:
      working-directory: './packages/backend'
```

## Troubleshooting

### Cache Issues
- The workflow automatically caches pnpm store based on `pnpm-lock.yaml`
- Cache is restored even if the exact key doesn't match (uses restore-keys)

### Custom Commands
- All command inputs support full shell commands
- Use quotes for commands with special characters
- Commands run in the specified working directory

### Test Failures
- Tests are set to `continue-on-error: true` by default
- To make tests required, use a custom test command that exits with proper code