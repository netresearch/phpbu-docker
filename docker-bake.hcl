# docker-bake.hcl - Multi-platform build configuration
# Usage: docker bake [target]
# Reference: https://docs.docker.com/build/bake/

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "REPO" {
  default = "netresearch/phpbu-docker"
}

variable "VERSION" {
  default = "6.0"
}

variable "PHP_VERSION" {
  default = "8.5"
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

  tags = [
    "${REGISTRY}/${REPO}:${VERSION}",
    "${REGISTRY}/${REPO}:latest",
    "${REGISTRY}/${REPO}:php${PHP_VERSION}",
  ]

  labels = {
    "org.opencontainers.image.title"       = "phpbu-docker"
    "org.opencontainers.image.description" = "PHP Backup Utility Docker Image"
    "org.opencontainers.image.vendor"      = "Netresearch GmbH & Co. KG"
    "org.opencontainers.image.source"      = "https://github.com/netresearch/phpbu-docker"
    "org.opencontainers.image.licenses"    = "LGPL-3.0"
    "org.opencontainers.image.version"     = "${VERSION}"
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
  inherits   = ["phpbu"]
  platforms  = ["linux/amd64"]
  tags       = ["phpbu:dev"]
  output     = ["type=docker"]
  attest     = []
  cache-from = []
  cache-to   = []
}

# CI target for testing
target "ci" {
  inherits   = ["phpbu"]
  platforms  = ["linux/amd64"]
  tags       = ["phpbu:ci"]
  output     = ["type=docker"]
  attest     = []
  cache-from = []
  cache-to   = []
}
