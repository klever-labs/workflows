# Configuration Files in Docker Builds

This document explains how to include configuration files (like nginx.conf) in your Docker builds using the klever-labs/workflows.

## Overview

The docker-build workflow now supports downloading and using configuration files and Dockerfiles from the workflow-calls repository as tar.gz archives. This is particularly useful for:

- nginx.conf files for JavaScript/frontend applications
- Environment-specific configuration files
- Shared configuration templates
- Shared Dockerfiles for different languages/frameworks

## Directory Structure

```
workflows/
├── dockerfiles/         # Dockerfiles for different flavors
│   ├── Dockerfile.golang
│   ├── Dockerfile.javascript
│   ├── Dockerfile.python
│   └── entrypoint.sh
├── configs/             # Configuration files
│   ├── nginx.conf
│   ├── redis.conf
│   └── ...
└── scripts/
    └── prepare-release.sh  # Script to create release archives
```

## How It Works

### 1. Automatic Download

By default, the workflow will download both dockerfiles and configuration files as tar.gz archives:

```yaml
- name: Docker Build
  uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
  with:
    flavor: javascript
    use_default_dockerfiles: true  # Download dockerfiles.tar.gz (default)
    download_configs: true         # Download configs.tar.gz (default)
```

### 2. Preparing Files for Release

Use the provided script to create release archives:

```bash
# Run from the workflows repository root
./scripts/prepare-release.sh

# This creates two archives:
# - dockerfiles.tar.gz (contains dockerfiles/ directory)
# - configs.tar.gz (contains configs/ directory)

# Then create a release including these archives:
gh release create v1.0.0 dockerfiles.tar.gz configs.tar.gz
```

### 3. Using in Dockerfiles

The workflow extracts the archives, making files available in their respective directories:

```dockerfile
# Reference config files from the configs/ directory
COPY configs/nginx.conf /etc/nginx/conf.d/default.conf

# Or if you have a custom nginx.conf in your project root
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

## Example: JavaScript Application with Nginx

1. **nginx.conf** is included in the workflows repository
2. **Dockerfile.javascript** expects the nginx.conf file:
   ```dockerfile
   FROM nginx:alpine-slim
   COPY nginx.conf /etc/nginx/conf.d/default.conf
   COPY --from=builder /app/dist /usr/share/nginx/html
   ```
3. The workflow automatically downloads the config file during build

## Customizing Config Download

To disable automatic config download:

```yaml
- name: Docker Build
  uses: klever-labs/workflows/.github/workflows/docker-build.yml@main
  with:
    flavor: javascript
    download_configs: false  # Disable config download
```

This is useful when you want to use project-specific configuration files instead of the shared ones.

## Creating Release Assets

When creating a new release of the workflows repository, use the provided script to package configs:

```bash
./scripts/package-configs.sh
```

This will create a `configs.tar.gz` file that should be included in the release assets.

## Best Practices

1. **Keep configs generic**: Configuration files in the workflows repository should be generic templates
2. **Override when needed**: Projects can disable `download_configs` and provide their own configs
3. **Document requirements**: If a Dockerfile requires specific config files, document it clearly
4. **Use environment variables**: For environment-specific values, use environment variables in your configs

## Supported File Types

Currently, the workflow downloads files matching these patterns:
- `*.conf` - Configuration files
- `configs.tar.gz` - Archived configs directory

Additional patterns can be added by modifying the download step in the workflow.
