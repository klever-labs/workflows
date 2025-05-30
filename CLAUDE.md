# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains reusable, version-controlled GitHub Actions workflows and automation templates used across
the organization. It serves as a central location for managing CI/CD pipelines, deployment processes, linting,
testing, and other DevOps tasks consistently across all applications and services.

By centralizing workflows, we reduce duplication, enforce best practices, and streamline development and deployment
processes across projects.

## Architecture Overview

### Directory Structure

```text
workflows/
│
├── README.md                # Overview, usage instructions, and contributing guidelines
├── LICENSE                  # MIT license
├── .github/
│   └── workflows/           # All workflows - both internal and reusable
│       ├── ci.yml           # Internal: CI for this repository
│       ├── release.yml      # Internal: Automated release creation
│       ├── test-workflows.yml # Internal: Test workflow syntax
│       ├── node-ci.yml      # Reusable: Complete Node.js CI workflow
│       ├── node-ci-simple.yml # Reusable: Simplified Node.js CI
│       ├── docker-build.yml # Reusable: Multi-registry Docker build
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
│   └── setup-pnpm/          # pnpm setup with caching
│       ├── action.yml
│       └── README.md
│
├── dockerfiles/             # Dockerfiles for different build flavors
│   └── Dockerfile.javascript
│
├── configs/                 # Configuration files for Docker builds
│   └── nginx.conf
│
├── scripts/                 # Utility scripts
│   ├── prepare-release.sh   # Create release archives
│   └── test-*.sh           # Test scripts
│
└── docs/                    # Documentation
    ├── usage.md
    ├── conventions.md
    ├── configuration-files.md
    └── examples/
        ├── node-pnpm-ci.md
        └── docker-build.md
```

### Workflow Organization

- **Internal workflows**: Prefixed with repo management tasks (e.g., `ci.yml`)
- **Reusable workflows**: Clear, descriptive names for external use
- **Technology-specific**: Include technology in name (e.g., `node-build.yml`, `python-test.yml`)
- **Scripts** (`scripts/`): Supporting scripts that workflows depend on
- **Documentation** (`docs/`): Detailed usage guides and conventions

### Naming Conventions

- Use kebab-case for workflow files: `build-and-test.yml`
- Technology-specific workflows: `<tech>-<action>.yml` (e.g., `node-build.yml`, `python-test.yml`)
- Environment-specific workflows: `deploy-<env>.yml` (e.g., `deploy-staging.yml`)
- Use descriptive job and step names in workflows

## Common Commands

### Validating Workflows

```bash
# Validate workflow syntax locally (requires act or actionlint)
actionlint .github/workflows/*.yml

# Test workflows locally with act
act -l  # List available workflows
act push  # Run push event workflows
```

### Working with GitHub CLI

```bash
# List workflows in a repository
gh workflow list

# View workflow runs
gh run list

# Download workflow artifacts
gh run download <run-id>
```

## Development Guidelines

### When Creating Workflows

1. Always use the latest stable action versions unless specific version is required
2. Pin third-party actions to full commit SHA for security
3. Use workflow inputs for configuration flexibility
4. Include clear documentation in workflow comments
5. Test workflows in a feature branch before merging

### Reusable Workflow Pattern

```yaml
on:
  workflow_call:
    inputs:
      # Define inputs here
    secrets:
      # Define required secrets here
```

### Security Considerations

- Never hardcode secrets - use GitHub Secrets
- Limit permissions using `permissions:` key
- Review third-party actions before use
- Use environment protection rules for sensitive deployments

## 🤖 Role of Claude

Claude is used as a collaborative agent to:

- Help design and optimize GitHub Actions workflows
- Generate and refactor CI/CD templates
- Suggest improvements in structure, naming, and automation logic
- Accelerate the creation of consistent, maintainable DevOps tooling

Claude is treated as an extension of our engineering process — focused on efficiency and consistency,
not as a replacement for decision-making or judgment.

## ✅ Integration Approach

Claude contributes to this repository via:

- **Prompt-based suggestions:** Developers use Claude to explore ideas or generate YAML/scripts
- **Code reviews or cleanups:** Claude may suggest improvements to PRs and internal standards
- **Prototyping workflows:** Claude can bootstrap new reusable workflows which are then iterated by engineers

## ⚖️ Oversight and Use Guidelines

Claude's output is intended to **accelerate**, not automate, our engineering workflows.

- Use Claude to reduce boilerplate and increase consistency.
- All Claude-assisted contributions are reviewed as part of normal PR workflow.
- Do not use Claude to generate sensitive logic (e.g., secrets management or compliance-critical flows)
  without engineer validation.

You are encouraged to experiment, iterate, and improve Claude-generated content as you would any other code artifact.

## 💬 Labeling Suggestions

To maintain transparency and collaboration:

- Optionally tag PRs or commits with `[claude-assisted]` to indicate AI support.
- Document significant Claude usage in PR descriptions if it influenced design decisions.

## 🧑‍💻 Maintainers

For guidance on how to use Claude in this repository or to propose updates to this policy, reach out to:

- `@your-name` – DevOps / Platform Engineering
- `@another-name` – Workflow Standards Maintainer
