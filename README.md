# Klever Labs Workflows

This repository contains reusable, version-controlled GitHub Actions workflows and automation templates used across
the Klever Labs organization. It serves as a central location for managing CI/CD pipelines, deployment processes,
linting, testing, and other DevOps tasks consistently across all applications and services.

By centralizing workflows, we reduce duplication, enforce best practices, and streamline development and deployment
processes across projects.

## Table of Contents

- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Usage](#usage)
- [Available Workflows](#available-workflows)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

To use a workflow from this repository in your project:

```yaml
name: Build and Test
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: klever-labs/workflows/.github/workflows/build.yml@main
    with:
      node-version: '18'
    secrets: inherit
```

## Repository Structure

```text
workflows/
│
├── README.md                # This file
├── LICENSE                  # MIT License
├── .github/
│   └── workflows/           # All workflows - both internal and reusable
│       ├── ci.yml           # Internal: CI for this repository
│       ├── build.yml        # Reusable: shared build pipeline
│       ├── test.yml         # Reusable: shared testing pipeline
│       ├── deploy.yml       # Reusable: deploy to staging/production
│       ├── lint.yml         # Reusable: linting for various languages
│       ├── node-build.yml   # Reusable: Node.js build steps
│       ├── python-test.yml  # Reusable: Python testing steps
│       ├── docker-deploy.yml # Reusable: Docker-based deployment
│       └── notify-slack.yml # Reusable: Slack notifications
│
├── actions/                 # Composite actions for reusable steps
│   ├── setup-node/          # Node.js setup with caching
│   │   └── action.yml
│   ├── cache-dependencies/  # Smart dependency caching
│   │   └── action.yml
│   └── notify-slack/        # Send Slack notifications
│       └── action.yml
│
├── scripts/                 # Utility scripts
│   └── cleanup-temp.sh
│
└── docs/                    # Documentation
    ├── usage.md
    └── conventions.md
```

## Usage

### Using Reusable Workflows

Reusable workflows from the `.github/workflows/` directory can be called from any repository in the organization:

```yaml
jobs:
  test:
    uses: klever-labs/workflows/.github/workflows/test.yml@main
    with:
      test-framework: jest
      coverage-threshold: 80
```

### Using Templates

Technology-specific workflows from the `.github/workflows/` directory provide parameterized components:

```yaml
jobs:
  build-node:
    uses: klever-labs/workflows/.github/workflows/node-build.yml@main
    with:
      node-version: '18'
      npm-registry: 'https://npm.pkg.github.com'
```

### Workflow Inputs and Secrets

Most workflows accept inputs for customization and can inherit secrets:

```yaml
jobs:
  deploy:
    uses: klever-labs/workflows/.github/workflows/deploy.yml@main
    with:
      environment: production
      aws-region: us-east-1
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Using Composite Actions

Composite actions provide reusable steps that can be used within your workflow jobs:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js with caching
        uses: klever-labs/workflows/actions/setup-node@main
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Cache project dependencies
        uses: klever-labs/workflows/actions/cache-dependencies@main
        with:
          package-manager: 'npm'
          
      - name: Build and test
        run: |
          npm ci
          npm test
          npm run build
```

## Available Workflows

### Core Workflows

- **build.yml** - Standard build pipeline with caching and artifact management
- **test.yml** - Comprehensive testing pipeline with coverage reporting
- **deploy.yml** - Multi-environment deployment workflow
- **lint.yml** - Multi-language linting and code quality checks
- **node-ci.yml** - Complete Node.js CI workflow with pnpm support
- **node-ci-simple.yml** - Simplified Node.js CI in a single job

### Technology-Specific Workflows

- **node-build.yml** - Node.js specific build steps with npm/yarn support
- **python-test.yml** - Python testing with test framework and coverage
- **docker-deploy.yml** - Docker image building and registry push
- **notify-slack.yml** - Slack notifications for workflow events

### Composite Actions

**Note**: These actions can only be used directly in your workflows, NOT within our reusable workflows.

- **actions/setup-pnpm** - pnpm setup with automatic caching (see [usage notes](actions/setup-pnpm/README.md))

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork and Clone** - Fork this repository and clone to your local machine
2. **Branch** - Create a feature branch (`feature/your-feature-name`)
3. **Test** - Test your workflows thoroughly
4. **Document** - Update documentation as needed
5. **Pull Request** - Submit a PR with a clear description

### Workflow Development Guidelines

- Use semantic versioning for major changes
- Include comprehensive comments in workflows
- Test workflows in a separate repository first
- Follow the naming conventions in `docs/conventions.md`
- Ensure workflows are idempotent and handle errors gracefully

### Security

- Never hardcode secrets or sensitive information
- Use `GITHUB_TOKEN` with minimal required permissions
- Pin action versions to full SHA for third-party actions
- Review and approve all workflow changes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Maintenance

For questions, issues, or contributions, please contact:

- DevOps Team: <devops@klever-labs.com>
- GitHub Issues: [Create an issue](https://github.com/klever-labs/workflows/issues)

---
Made with love by the Klever Labs DevOps Team
