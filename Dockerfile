# syntax=docker/dockerfile:1.23
#########################################
# Base stage - minimal runtime dependencies
# Pin to digest for supply chain security (renovate will update)
FROM php:8.5-alpine@sha256:fa8599174dc8a1a8a9dabb42e054e6874d0f69bc3ea0a14176b7f9f74b7765e9 AS base

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

# Install PHP FTP extension for FTP sync adapter
RUN docker-php-ext-install ftp

#########################################
# Build stage - compile dependencies (minimal)
FROM base AS build-minimal

# Composer in build stage only (not in final image)
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Install Composer from official image (pinned for reproducibility)
COPY --from=composer:2@sha256:698d3801b2a622ace460c4743c781282fcbcb733a4cbf8b31c44731e846585e8 /usr/bin/composer /usr/bin/composer

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

# Note: PHP FTP extension already installed in base-full stage

# Install Composer from official image (pinned for reproducibility)
COPY --from=composer:2@sha256:698d3801b2a622ace460c4743c781282fcbcb733a4cbf8b31c44731e846585e8 /usr/bin/composer /usr/bin/composer

# Copy full variant dependency files
COPY --chown=phpbu:phpbu app/full/composer.json ./composer.json
COPY --chown=phpbu:phpbu app/full/composer.lock ./composer.lock

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
# Final stage - minimal production image
FROM base AS minimal

# PHP security hardening
COPY app/php-hardening.ini /usr/local/etc/php/conf.d/99-hardening.ini

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

# Copy entrypoint script (not in build stage, must be copied separately)
COPY --chmod=755 --chown=phpbu:phpbu app/docker-entrypoint.sh /app/docker-entrypoint.sh

# Create directories with correct permissions
# tz.ini owned by phpbu so entrypoint can set timezone from TZ env var
RUN mkdir -p /backups && chown phpbu:phpbu /backups && \
    touch /usr/local/etc/php/conf.d/tz.ini && chown phpbu:phpbu /usr/local/etc/php/conf.d/tz.ini

# Security: Switch to non-root user
USER phpbu

# Volumes for config and backup output
VOLUME ["/backups"]

# Healthcheck - verify phpbu is functional
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/app/vendor/bin/phpbu", "--version"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["--help"]

#########################################
# Final stage - full production image
FROM base-full AS full

# PHP security hardening
COPY app/php-hardening.ini /usr/local/etc/php/conf.d/99-hardening.ini

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

# Copy entrypoint script (not in build stage, must be copied separately)
COPY --chmod=755 --chown=phpbu:phpbu app/docker-entrypoint.sh /app/docker-entrypoint.sh

# Create directories with correct permissions
# tz.ini owned by phpbu so entrypoint can set timezone from TZ env var
RUN mkdir -p /backups && chown phpbu:phpbu /backups && \
    touch /usr/local/etc/php/conf.d/tz.ini && chown phpbu:phpbu /usr/local/etc/php/conf.d/tz.ini

# Security: Switch to non-root user
USER phpbu

# Volumes for config and backup output
VOLUME ["/backups"]

# Healthcheck - verify phpbu is functional
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/app/vendor/bin/phpbu", "--version"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["--help"]
