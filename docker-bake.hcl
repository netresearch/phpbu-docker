# docker-bake.hcl - Multi-platform build configuration
# Usage: docker buildx bake [target]
# Reference: https://docs.docker.com/build/bake/

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "REPO" {
  default = "netresearch/phpbu-docker"
}

# phpbu version from composer.lock
variable "PHPBU_VERSION" {
  default = "6.0.30"
}

# phpbu major.minor for floating tag
variable "PHPBU_MINOR" {
  default = "6.0"
}

# phpbu major for floating tag
variable "PHPBU_MAJOR" {
  default = "6"
}

# Build date for unique tags (YYYY-MM-DD)
variable "BUILD_DATE" {
  default = ""
}

# Git commit short SHA
variable "GIT_SHA" {
  default = ""
}

# Default group builds all production variants
group "default" {
  targets = ["minimal", "full"]
}

# Alias: phpbu = minimal (for backwards compatibility)
target "phpbu" {
  inherits = ["minimal"]
}

# Minimal variant - database clients only (~50MB)
target "minimal" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "minimal"

  # Multi-platform builds
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]

  # Tags: version-based + latest + minimal
  tags = compact([
    "${REGISTRY}/${REPO}:${PHPBU_MAJOR}",
    "${REGISTRY}/${REPO}:${PHPBU_MINOR}",
    "${REGISTRY}/${REPO}:${PHPBU_VERSION}",
    notequal("", BUILD_DATE) ? "${REGISTRY}/${REPO}:${PHPBU_VERSION}-${BUILD_DATE}" : "",
    notequal("", GIT_SHA) ? "${REGISTRY}/${REPO}:${PHPBU_VERSION}-${GIT_SHA}" : "",
    "${REGISTRY}/${REPO}:latest",
    "${REGISTRY}/${REPO}:minimal",
  ])

  labels = {
    "org.opencontainers.image.title"       = "phpbu-docker"
    "org.opencontainers.image.description" = "PHP Backup Utility Docker Image (minimal)"
    "org.opencontainers.image.vendor"      = "Netresearch DTT GmbH"
    "org.opencontainers.image.source"      = "https://github.com/netresearch/phpbu-docker"
    "org.opencontainers.image.licenses"    = "LGPL-3.0"
    "org.opencontainers.image.version"     = "${PHPBU_VERSION}"
    "org.opencontainers.image.variant"     = "minimal"
  }

  # Supply chain security
  attest = [
    "type=provenance,mode=max",
    "type=sbom"
  ]

  # Build cache
  cache-from = ["type=gha,scope=minimal"]
  cache-to   = ["type=gha,scope=minimal,mode=max"]
}

# Full variant - all sync adapters (~150MB)
target "full" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "full"

  # Multi-platform builds
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]

  # Tags: full-specific tags
  tags = compact([
    "${REGISTRY}/${REPO}:${PHPBU_VERSION}-full",
    notequal("", BUILD_DATE) ? "${REGISTRY}/${REPO}:${PHPBU_VERSION}-full-${BUILD_DATE}" : "",
    notequal("", GIT_SHA) ? "${REGISTRY}/${REPO}:${PHPBU_VERSION}-full-${GIT_SHA}" : "",
    "${REGISTRY}/${REPO}:full",
  ])

  labels = {
    "org.opencontainers.image.title"       = "phpbu-docker"
    "org.opencontainers.image.description" = "PHP Backup Utility Docker Image (full - all sync adapters)"
    "org.opencontainers.image.vendor"      = "Netresearch DTT GmbH"
    "org.opencontainers.image.source"      = "https://github.com/netresearch/phpbu-docker"
    "org.opencontainers.image.licenses"    = "LGPL-3.0"
    "org.opencontainers.image.version"     = "${PHPBU_VERSION}"
    "org.opencontainers.image.variant"     = "full"
  }

  # Supply chain security
  attest = [
    "type=provenance,mode=max",
    "type=sbom"
  ]

  # Build cache
  cache-from = ["type=gha,scope=full"]
  cache-to   = ["type=gha,scope=full,mode=max"]
}

# Development target (single platform, no push)
target "dev" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "minimal"
  platforms  = ["linux/amd64"]
  tags       = ["phpbu:dev"]
  output     = ["type=docker"]
}

# CI target for testing (minimal variant)
target "ci" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "minimal"
  platforms  = ["linux/amd64"]
  tags       = ["phpbu:ci"]
  output     = ["type=docker"]
}

# CI target for testing full variant
target "ci-full" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "full"
  platforms  = ["linux/amd64"]
  tags       = ["phpbu:ci-full"]
  output     = ["type=docker"]
}
