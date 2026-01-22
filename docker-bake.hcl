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

# Shared configuration for all targets
group "default" {
  targets = ["phpbu"]
}

# Main phpbu image target
target "phpbu" {
  context    = "."
  dockerfile = "Dockerfile"

  # Multi-platform builds
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]

  # Tags based on phpbu version
  # Example: 6, 6.0, 6.0.30, 6.0.30-2026-01-22, 6.0.30-abc1234, latest
  tags = compact([
    "${REGISTRY}/${REPO}:${PHPBU_MAJOR}",
    "${REGISTRY}/${REPO}:${PHPBU_MINOR}",
    "${REGISTRY}/${REPO}:${PHPBU_VERSION}",
    notequal("", BUILD_DATE) ? "${REGISTRY}/${REPO}:${PHPBU_VERSION}-${BUILD_DATE}" : "",
    notequal("", GIT_SHA) ? "${REGISTRY}/${REPO}:${PHPBU_VERSION}-${GIT_SHA}" : "",
    "${REGISTRY}/${REPO}:latest",
  ])

  labels = {
    "org.opencontainers.image.title"       = "phpbu-docker"
    "org.opencontainers.image.description" = "PHP Backup Utility Docker Image"
    "org.opencontainers.image.vendor"      = "Netresearch GmbH & Co. KG"
    "org.opencontainers.image.source"      = "https://github.com/netresearch/phpbu-docker"
    "org.opencontainers.image.licenses"    = "LGPL-3.0"
    "org.opencontainers.image.version"     = "${PHPBU_VERSION}"
  }

  # Supply chain security
  attest = [
    "type=provenance,mode=max",
    "type=sbom"
  ]

  # Build cache
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}

# Development target (single platform, no push)
target "dev" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64"]
  tags       = ["phpbu:dev"]
  output     = ["type=docker"]
}

# CI target for testing
target "ci" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64"]
  tags       = ["phpbu:ci"]
  output     = ["type=docker"]
}
