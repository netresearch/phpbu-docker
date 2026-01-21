# Contributing to phpbu-docker

Thank you for your interest in contributing to phpbu-docker!

## Development Setup

### Prerequisites

- Docker with Buildx support
- Git

### Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/netresearch/phpbu-docker.git
   cd phpbu-docker
   ```

2. Build locally:
   ```bash
   docker buildx bake dev
   ```

3. Test your changes:
   ```bash
   docker run --rm phpbu:dev --version
   docker run --rm phpbu:dev --help
   ```

### Using Docker Compose

```bash
# Build and run
docker compose build phpbu
docker compose run --rm phpbu --version

# Development mode
docker compose up dev
```

## Making Changes

### Branch Naming

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `security/` - Security improvements

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
```
feat(dockerfile): add arm64 support
fix(security): run as non-root user
docs(readme): update usage examples
```

## Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch from `main`
3. **Make** your changes
4. **Test** locally with `docker buildx bake ci`
5. **Lint** with hadolint: `docker run --rm -i hadolint/hadolint < Dockerfile`
6. **Submit** a pull request

### PR Requirements

- [ ] Dockerfile passes hadolint
- [ ] `docker buildx bake --print` validates bake file
- [ ] Image builds successfully
- [ ] `--version` and `--help` work
- [ ] No new critical/high vulnerabilities (Trivy)
- [ ] Documentation updated if needed

## Testing

### Build Validation

```bash
# Validate bake configuration
docker buildx bake --print

# Build CI target
docker buildx bake ci

# Run basic tests
docker run --rm phpbu:ci --version
docker run --rm phpbu:ci --help
```

### Security Scanning

```bash
# Run Trivy locally
docker run --rm aquasec/trivy image phpbu:ci
```

### Lint Dockerfile

```bash
docker run --rm -i hadolint/hadolint < Dockerfile
```

## Code Style

### Dockerfile

- Use multi-stage builds
- Minimize layers
- Run as non-root user
- Include health checks
- Add OCI labels
- Follow hadolint recommendations

### HCL (docker-bake.hcl)

- Use consistent indentation (2 spaces)
- Group related targets
- Document complex configurations

## Release Process

Releases are automated via GitHub Actions:

1. Create a tag: `git tag v1.0.0`
2. Push the tag: `git push origin v1.0.0`
3. CI builds, tests, signs, and pushes the image

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/netresearch/phpbu-docker/issues)
- **Discussions**: [GitHub Discussions](https://github.com/netresearch/phpbu-docker/discussions)
- **Security**: security@netresearch.de

## License

By contributing, you agree that your contributions will be licensed under the LGPL-3.0 License.
