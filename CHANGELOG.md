# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial Docker image for phpbu 6.0.x
- Multi-architecture support (amd64, arm64)
- Multi-stage Dockerfile with security hardening
- Non-root user execution (UID 1000)
- Cosign image signing with keyless OIDC
- SBOM generation (SPDX format)
- SLSA provenance attestation
- Daily vulnerability scanning with Trivy
- Secrets detection with Gitleaks
- Dependabot for automated dependency updates
- Example configurations for MySQL, PostgreSQL, S3 sync
- GitHub Actions CI/CD workflows
- Weekly security rebuilds
- CODEOWNERS for code review enforcement

### Security
- All GitHub Actions pinned to SHA for supply chain security
- Container runs as non-root user
- Minimal Alpine base image
- No build tools in production image
- Read-only filesystem compatible

## [1.0.0] - Unreleased

Initial release.

[Unreleased]: https://github.com/netresearch/phpbu-docker/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/netresearch/phpbu-docker/releases/tag/v1.0.0
