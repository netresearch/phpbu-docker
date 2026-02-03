# syntax=docker/dockerfile:1.14
#########################################
# Base stage - minimal runtime dependencies
# Pin to digest for supply chain security (renovate will update)
FROM php:8.5-alpine@sha256:ef23f63dac3c23d4f392b416b6324fdf9f69c642c0c8556d20c0627ad522f27e AS base

# Security: Create non-root user early
RUN addgroup -g 1000 phpbu && \
    adduser -D -u 1000 -G phpbu -s /sbin/nologin phpbu

# Install runtime dependencies only
# Note: redis package includes redis-cli for Redis backups
# hadolint ignore=DL3018
RUN apk --no-cache --update upgrade && \
    apk --no-cache add \
        mysql-client \
        postgresql-client \
        mongodb-tools \
        redis \
        ca-certificates \
        tzdata && \
    # Remove apk cache, temp files, and unnecessary files
    rm -rf /var/cache/apk/* /tmp/* /root/.cache /var/log/*

WORKDIR /app

#########################################
# Base-full stage - additional tools for full variant
FROM base AS base-full

# Additional tools for sync adapters and encryption
# hadolint ignore=DL3018
RUN apk --no-cache add \
        rsync \
        gnupg \
        openssh-client \
        curl && \
    rm -rf /var/cache/apk/* /tmp/*

#########################################
# Build stage - compile dependencies (minimal)
FROM base AS build-minimal

# Composer in build stage only (not in final image)
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Install Composer from official image (pinned for reproducibility)
COPY --from=composer:2@sha256:c404e6f07bdebf8a8c605be5b5fab88eef737f6e4acfba3651d39c824ce224d4 /usr/bin/composer /usr/bin/composer

# Copy dependency files first (layer caching)
COPY --chown=phpbu:phpbu app/composer.json app/composer.lock ./

# Install dependencies with optimization
RUN composer install \
    --no-ansi \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader \
    --classmap-authoritative && \
    # Clean up composer cache
    rm -rf /tmp/composer

#########################################
# Build stage - compile dependencies (full)
FROM base-full AS build-full

# Composer in build stage only (not in final image)
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Install Composer from official image (pinned for reproducibility)
COPY --from=composer:2@sha256:c404e6f07bdebf8a8c605be5b5fab88eef737f6e4acfba3651d39c824ce224d4 /usr/bin/composer /usr/bin/composer

# Copy full variant dependency files
COPY --chown=phpbu:phpbu app/composer-full.json ./composer.json

# Install dependencies with optimization (generates fresh lock file)
RUN composer install \
    --no-ansi \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader \
    --classmap-authoritative && \
    # Clean up composer cache
    rm -rf /tmp/composer

#########################################
# Final stage - minimal production image
FROM base AS minimal

# OCI image labels
LABEL org.opencontainers.image.title="phpbu-docker" \
      org.opencontainers.image.description="PHP Backup Utility Docker Image (minimal)" \
      org.opencontainers.image.vendor="Netresearch DTT GmbH" \
      org.opencontainers.image.source="https://github.com/netresearch/phpbu-docker" \
      org.opencontainers.image.documentation="https://github.com/netresearch/phpbu-docker#readme" \
      org.opencontainers.image.licenses="LGPL-3.0" \
      org.opencontainers.image.base.name="docker.io/library/php:8.5-alpine" \
      org.opencontainers.image.variant="minimal"

# Copy built application from build stage
COPY --from=build-minimal --chown=phpbu:phpbu /app /app

# Create directories with correct permissions
RUN mkdir -p /backups && chown phpbu:phpbu /backups

# Security: Switch to non-root user
USER phpbu

# Volumes for config and backup output
VOLUME ["/backups"]

# Healthcheck - verify phpbu is functional
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/app/vendor/bin/phpbu", "--version"]

ENTRYPOINT ["/app/vendor/bin/phpbu"]
CMD ["--help"]

#########################################
# Final stage - full production image
FROM base-full AS full

# OCI image labels
LABEL org.opencontainers.image.title="phpbu-docker" \
      org.opencontainers.image.description="PHP Backup Utility Docker Image (full - all sync adapters)" \
      org.opencontainers.image.vendor="Netresearch DTT GmbH" \
      org.opencontainers.image.source="https://github.com/netresearch/phpbu-docker" \
      org.opencontainers.image.documentation="https://github.com/netresearch/phpbu-docker#readme" \
      org.opencontainers.image.licenses="LGPL-3.0" \
      org.opencontainers.image.base.name="docker.io/library/php:8.5-alpine" \
      org.opencontainers.image.variant="full"

# Copy built application from build stage
COPY --from=build-full --chown=phpbu:phpbu /app /app

# Create directories with correct permissions
RUN mkdir -p /backups && chown phpbu:phpbu /backups

# Security: Switch to non-root user
USER phpbu

# Volumes for config and backup output
VOLUME ["/backups"]

# Healthcheck - verify phpbu is functional
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/app/vendor/bin/phpbu", "--version"]

ENTRYPOINT ["/app/vendor/bin/phpbu"]
CMD ["--help"]
