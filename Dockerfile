# syntax=docker/dockerfile:1.9
#########################################
# Base stage - minimal runtime dependencies
# Pin to digest for supply chain security (renovate will update)
FROM php:8.5-alpine@sha256:c92a69cf4422b41524c380886d0ef15382468a17e1e94c2fb848b638103afe8b AS base

# Security: Create non-root user early
RUN addgroup -g 1000 phpbu && \
    adduser -D -u 1000 -G phpbu -s /sbin/nologin phpbu

# Install runtime dependencies only
# Note: redis package includes redis-cli for Redis backups
RUN apk --no-cache --update upgrade && \
    apk --no-cache add \
        mysql-client \
        postgresql-client \
        mongodb-tools \
        redis \
        ca-certificates \
        tzdata && \
    # Remove apk cache and temp files
    rm -rf /var/cache/apk/* /tmp/*

WORKDIR /app

#########################################
# Build stage - compile dependencies
FROM base AS build

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
# Final stage - minimal production image
FROM base AS final

LABEL org.opencontainers.image.title="phpbu-docker" \
      org.opencontainers.image.description="PHP Backup Utility Docker Image" \
      org.opencontainers.image.vendor="Netresearch DTT GmbH" \
      org.opencontainers.image.source="https://github.com/netresearch/phpbu-docker" \
      org.opencontainers.image.licenses="LGPL-3.0"

# Copy built application from build stage
COPY --from=build --chown=phpbu:phpbu /app /app

# Create directories with correct permissions
RUN mkdir -p /backups && chown phpbu:phpbu /backups && \
    # Remove unnecessary files to reduce image size
    rm -rf /var/cache/apk/* /tmp/* /root/.ash_history 2>/dev/null || true

# Security: Switch to non-root user
USER phpbu

# Health check (validates phpbu is functional)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/app/vendor/bin/phpbu", "--version"]

# Volumes for config and backup output
VOLUME ["/backups"]

ENTRYPOINT ["/app/vendor/bin/phpbu"]
CMD ["--help"]
