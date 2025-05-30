# Setup pnpm Action

This composite action sets up pnpm with intelligent caching.

## ⚠️ Important Usage Note

This action **CANNOT** be used inside our reusable workflows (in `.github/workflows/`) due to GitHub Actions limitations.

### ✅ Where it CAN be used

1. **Directly in external repositories**

   ```yaml
   # In another repo's workflow
   steps:
     - uses: actions/checkout@v4
     - uses: klever-labs/workflows/actions/setup-pnpm@main
       with:
         version: '8'
   ```

2. **Before calling our reusable workflows**

   ```yaml
   jobs:
     setup:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: klever-labs/workflows/actions/setup-pnpm@main
     
     build:
       needs: setup
       uses: klever-labs/workflows/.github/workflows/node-ci.yml@main
   ```

### ❌ Where it CANNOT be used

- Inside `node-ci.yml` or `node-ci-simple.yml` or any reusable workflow

## Why?

When a reusable workflow is called from an external repository, GitHub Actions cannot resolve local action paths.
 This is a security feature to prevent workflows from executing arbitrary code.

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `version` | pnpm version to install | `8` |
| `working-directory` | Directory containing pnpm-lock.yaml | `.` |
| `run-install` | Whether to run pnpm install | `true` |
| `install-args` | Arguments for pnpm install | `--frozen-lockfile` |

## Outputs

| Output | Description |
|--------|-------------|
| `store-path` | The pnpm store directory path |
| `cache-hit` | Whether the cache was hit |

## Example

```yaml
- uses: klever-labs/workflows/actions/setup-pnpm@main
  with:
    version: '9'
    working-directory: './frontend'
```
