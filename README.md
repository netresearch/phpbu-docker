# phpbu Docker

Production-ready Docker image for [phpbu](https://phpbu.de/) - PHP Backup Utility with comprehensive backup, sync, and cleanup capabilities.

## Features

- PHP 8.4 with security hardening
- Non-root container execution (UID 1000)
- Multi-architecture support (amd64, arm64)
- Pre-configured for MySQL, PostgreSQL, MongoDB, Redis backups
- S3, SFTP, Dropbox sync support
- Cosign-signed images with SBOM
- Health checks and observability

## Quick Start

```bash
# Pull the image
docker pull ghcr.io/netresearch/phpbu-docker:latest

# Run a backup
docker run --rm \
  -v ./backup.json:/config/backup.json:ro \
  -v ./backups:/backups \
  ghcr.io/netresearch/phpbu-docker:latest \
  --configuration=/config/backup.json
```

## Usage

### Basic Backup with JSON Config

Create a `backup.json` configuration file:

```json
{
  "verbose": true,
  "backups": [
    {
      "name": "MySQL Backup",
      "source": {
        "type": "mysqldump",
        "options": {
          "host": "mysql",
          "user": "root",
          "password": "secret",
          "databases": "myapp"
        }
      },
      "target": {
        "dirname": "/backups",
        "filename": "mysql-%Y%m%d-%H%i%s.sql",
        "compress": "gzip"
      }
    }
  ]
}
```

Run the backup:

```bash
docker run --rm \
  -v ./backup.json:/config/backup.json:ro \
  -v ./backups:/backups \
  --network myapp_network \
  ghcr.io/netresearch/phpbu-docker:latest \
  --configuration=/config/backup.json
```

### Docker Compose

```yaml
services:
  phpbu:
    image: ghcr.io/netresearch/phpbu-docker:latest
    volumes:
      - ./config:/config:ro
      - ./backups:/backups
    environment:
      - TZ=UTC
    depends_on:
      - mysql
    profiles:
      - backup
    command: ["--configuration=/config/backup.json"]

  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: myapp
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

Run backup manually:

```bash
docker compose --profile backup run --rm phpbu
```

### Scheduled Backups

For scheduled backups, use the host's cron or a scheduler container:

```bash
# Add to crontab
0 2 * * * docker compose --profile backup run --rm phpbu
```

Or use a scheduler service in compose:

```yaml
services:
  scheduler:
    image: mcuadros/ofelia:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    labels:
      ofelia.job-run.phpbu.schedule: "0 0 2 * * *"
      ofelia.job-run.phpbu.container: "phpbu"
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | `UTC` |

### Volume Mounts

| Path | Purpose |
|------|---------|
| `/config` | Configuration files (read-only recommended) |
| `/backups` | Backup output directory |

### Supported Backup Sources

- **Databases**: MySQL/MariaDB, PostgreSQL, MongoDB, Redis, InfluxDB
- **Files**: Directory, Tar archives
- **Applications**: Arangodump, Elasticdump, Ldapdump

### Supported Sync Targets

- Amazon S3 / S3-compatible storage
- SFTP/SCP
- Rsync
- Dropbox
- Google Drive
- Azure Blob Storage
- Openstack Swift

### Supported Cleanup Strategies

- **Capacity**: Keep backups up to specified size
- **Quantity**: Keep N most recent backups
- **Outdated**: Remove backups older than specified time

## Examples

See the [examples/](examples/) directory for complete configuration examples:

- `mysql-backup.json` - MySQL database backup
- `postgres-backup.json` - PostgreSQL database backup
- `s3-sync.json` - File backup with S3 sync

## Building

### Local Build

```bash
# Build for current platform
docker bake dev

# Build for multiple platforms
docker bake
```

### Development

```bash
# Start development environment
docker compose up -d dev

# Run phpbu with custom config
docker compose run --rm phpbu --configuration=/config/backup.json
```

## Security

- Runs as non-root user (UID 1000)
- Read-only root filesystem compatible
- Security scanning via Trivy in CI
- Cosign-signed images with SLSA provenance
- See [SECURITY.md](SECURITY.md) for vulnerability reporting

### Verify Image Signature

```bash
cosign verify ghcr.io/netresearch/phpbu-docker:latest \
  --certificate-identity-regexp "https://github.com/netresearch/phpbu-docker" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

## Architecture Support

| Platform | Support |
|----------|---------|
| linux/amd64 | Full |
| linux/arm64 | Full |

## Image Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable release |
| `6.0` | phpbu 6.0.x series |
| `php8.4` | PHP 8.4 base image |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the LGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

phpbu itself is created by [Sebastian Feldmann](https://github.com/sebastianfeldmann) and licensed under the BSD-3-Clause license.

## Links

- [phpbu Documentation](https://phpbu.de/documentation.html)
- [phpbu GitHub](https://github.com/sebastianfeldmann/phpbu)
- [GitHub Container Registry](https://ghcr.io/netresearch/phpbu-docker)
