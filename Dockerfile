# syntax=docker/dockerfile:1.9
#########################################
# Base stage - minimal runtime dependencies
FROM php:8.4-alpine AS base

# Security: Create non-root user early
RUN addgroup -g 1000 phpbu && \
    adduser -D -u 1000 -G phpbu phpbu

# Install runtime dependencies only
RUN apk --no-cache --update upgrade && \
    apk --no-cache add \
        mysql-client \
        postgresql-client \
        mongodb-tools \
        redis \
        ca-certificates \
        tzdata

WORKDIR /app

#########################################
# Build stage - compile dependencies
FROM base AS build

# Composer in build stage only (not in final image)
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Install Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

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
    --classmap-authoritative

#########################################
# Final stage - minimal production image
FROM base AS final

LABEL org.opencontainers.image.title="phpbu-docker" \
      org.opencontainers.image.description="PHP Backup Utility Docker Image" \
      org.opencontainers.image.vendor="Netresearch GmbH & Co. KG" \
      org.opencontainers.image.source="https://github.com/netresearch/phpbu-docker" \
      org.opencontainers.image.licenses="LGPL-3.0"

# Copy built application from build stage
COPY --from=build --chown=phpbu:phpbu /app /app

# Create directories with correct permissions
RUN mkdir -p /backups && chown phpbu:phpbu /backups

# Security: Switch to non-root user
USER phpbu

# Health check (validates phpbu is functional)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/app/vendor/bin/phpbu", "--version"]

# Volumes for config and backup output
VOLUME ["/backups"]

ENTRYPOINT ["/app/vendor/bin/phpbu"]
CMD ["--help"]
