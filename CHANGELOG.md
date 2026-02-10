# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-02-10

### Added
- Runtime timezone support via `TZ` environment variable (sets PHP `date.timezone` at startup)
- Entrypoint wrapper script with TZ input validation

### Fixed
- Full variant composer files (`composer-full.json`) invisible to Renovate and Dependabot; moved to `app/full/composer.json` for native auto-update support

## 2026-02-05

### Changed
- Renovate: enable lockFileMaintenance, platformAutomerge, direct merge for bypass permissions
- CI: bump docker/login-action, shivammathur/setup-php, github/codeql-action

### Fixed
- CI: remove update-deps job, add workflow_dispatch trigger
- CI: use rebase merge (required_linear_history enabled)

## 2026-02-03

### Added
- GHCR package cleanup workflow for untagged versions
- PHP security hardening configuration (disable dangerous functions, secure defaults)
- Minimal and full image variants with version-specific tags (e.g., `6.0-minimal`, `6.0-full`)

### Fixed
- Use docker-bake.hcl for release tagging with immutable tags
- Update both composer.lock files in CI dependency updates
- Install PHP FTP extension in full variant

## 2026-02-02

### Added
- Auto-update composer.lock on push/schedule
- Auto-merge Docker digest updates
- Release configuration and container security improvements

### Fixed
- Container structure test for setuid binary detection
- CI: use PHP 8.5 for composer update
- Exclude Docker major version bumps from auto-merge

## 2026-01-22

### Added
- Enterprise security hardening and phpbu-version tagging
- Mermaid diagrams for workflow visualization
- Docker Scout integration

### Fixed
- GitHub Actions updated to latest versions
- Container test permissions and Docker Scout workflow syntax

## 2026-01-21

### Added
- Initial Docker image for phpbu 6.0.x on PHP 8.5 Alpine
- **Image variants**: `minimal` (~50MB) and `full` (~150MB) with all sync adapters
- Multi-architecture support (amd64, arm64)
- Multi-stage Dockerfile with security hardening
- Non-root user execution (UID 1000, no login shell)
- Cosign image signing with keyless OIDC
- SBOM generation (SPDX format)
- SLSA provenance attestation
- Daily vulnerability scanning with Trivy
- Secrets detection with Gitleaks
- Renovate for automated dependency updates
- Example configurations for MySQL, PostgreSQL, S3 sync
- GitHub Actions CI/CD workflows
- CODEOWNERS for code review enforcement
- HEALTHCHECK for container health monitoring

### Full Variant Includes
- AWS S3 SDK (`aws/aws-sdk-php`)
- Google Cloud Storage (`google/cloud-storage`)
- Azure Blob Storage (`microsoft/azure-storage-blob`)
- SFTP support (`phpseclib/phpseclib`)
- FTP support (`sebastianfeldmann/ftp` + ext-ftp)
- Dropbox SDK (`kunalvarma05/dropbox-php-sdk`)
- Additional tools: rsync, gnupg, openssh-client, curl
