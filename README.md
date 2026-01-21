# phpbu Docker

Production-ready Docker image for [phpbu](https://phpbu.de/) - PHP Backup Utility with comprehensive backup, sync, and cleanup capabilities.

## Features

- PHP 8.5 with security hardening
- Non-root container execution
- Multi-architecture support (amd64, arm64)
- Pre-configured for MySQL, PostgreSQL, MongoDB, Redis backups
- S3, SFTP, Dropbox sync support
- Scheduled backup execution via cron
- Health checks and observability

## Quick Start

```bash
# Pull the image
docker pull ghcr.io/sebastianfeldmann/phpbu:latest

# Run a backup
docker run --rm \
  -v ./phpbu.xml:/app/phpbu.xml:ro \
  -v ./backups:/backups \
  ghcr.io/sebastianfeldmann/phpbu:latest
```

## Usage

### Basic Backup

Create a `phpbu.xml` configuration file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpbu xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:noNamespaceSchemaLocation="http://schema.phpbu.de/6.0/phpbu.xsd">
  <backups>
    <backup name="mysql-backup">
      <source type="mysqldump">
        <option name="host" value="mysql"/>
        <option name="user" value="root"/>
        <option name="password" value="secret"/>
        <option name="databases" value="myapp"/>
      </source>
      <target dirname="/backups/mysql"
              filename="dump-%Y%m%d-%H%i.sql"
              compress="gzip"/>
    </backup>
  </backups>
</phpbu>
```

Run the backup:

```bash
docker run --rm \
  -v ./phpbu.xml:/app/phpbu.xml:ro \
  -v ./backups:/backups \
  --network myapp_network \
  ghcr.io/sebastianfeldmann/phpbu:latest
```

### Docker Compose

```yaml
services:
  phpbu:
    image: ghcr.io/sebastianfeldmann/phpbu:latest
    volumes:
      - ./phpbu.xml:/app/phpbu.xml:ro
      - ./backups:/backups
    environment:
      - TZ=UTC
    depends_on:
      - mysql
    profiles:
      - backup

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
| `PHPBU_CONFIG` | Config file path | `/app/phpbu.xml` |

### Volume Mounts

| Path | Purpose |
|------|---------|
| `/app/phpbu.xml` | Configuration file (read-only) |
| `/backups` | Backup output directory |
| `/app/.env` | Environment variables file |

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

### MySQL with S3 Sync

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpbu xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:noNamespaceSchemaLocation="http://schema.phpbu.de/6.0/phpbu.xsd">
  <backups>
    <backup name="mysql-s3">
      <source type="mysqldump">
        <option name="host" value="mysql"/>
        <option name="user" value="backup"/>
        <option name="password" value="%env:MYSQL_PASSWORD%"/>
        <option name="databases" value="production"/>
      </source>
      <target dirname="/backups/mysql"
              filename="prod-%Y%m%d-%H%i.sql"
              compress="gzip"/>
      <sync type="amazons3">
        <option name="key" value="%env:AWS_ACCESS_KEY_ID%"/>
        <option name="secret" value="%env:AWS_SECRET_ACCESS_KEY%"/>
        <option name="bucket" value="my-backups"/>
        <option name="region" value="eu-west-1"/>
        <option name="path" value="/mysql/"/>
      </sync>
      <cleanup type="quantity">
        <option name="amount" value="7"/>
      </cleanup>
    </backup>
  </backups>
</phpbu>
```

### PostgreSQL Backup

```xml
<backup name="postgres-backup">
  <source type="pgdump">
    <option name="host" value="postgres"/>
    <option name="user" value="postgres"/>
    <option name="password" value="%env:POSTGRES_PASSWORD%"/>
    <option name="database" value="myapp"/>
  </source>
  <target dirname="/backups/postgres"
          filename="dump-%Y%m%d.sql"
          compress="gzip"/>
</backup>
```

### MongoDB Backup

```xml
<backup name="mongo-backup">
  <source type="mongodump">
    <option name="host" value="mongo"/>
    <option name="user" value="admin"/>
    <option name="password" value="%env:MONGO_PASSWORD%"/>
    <option name="databases" value="myapp"/>
  </source>
  <target dirname="/backups/mongo"
          filename="dump-%Y%m%d"
          compress="gzip"/>
</backup>
```

### Directory Backup with Encryption

```xml
<backup name="files-encrypted">
  <source type="tar">
    <option name="path" value="/data/uploads"/>
  </source>
  <target dirname="/backups/files"
          filename="uploads-%Y%m%d.tar"
          compress="gzip"/>
  <crypt type="openssl">
    <option name="password" value="%env:BACKUP_ENCRYPTION_KEY%"/>
    <option name="algorithm" value="aes-256-cbc"/>
  </crypt>
</backup>
```

## Building

### Local Build

```bash
# Build for current platform
docker buildx bake

# Build for multiple platforms
docker buildx bake --set "*.platform=linux/amd64,linux/arm64"
```

### Development

```bash
# Start development environment
docker compose up -d

# Run tests
docker compose exec phpbu vendor/bin/phpunit

# Run phpbu with custom config
docker compose exec phpbu phpbu --configuration=/app/phpbu.xml
```

## Security

- Runs as non-root user (uid 1000)
- Read-only root filesystem compatible
- No shell in production image
- Security scanning via Trivy in CI
- See [SECURITY.md](SECURITY.md) for vulnerability reporting

## Architecture Support

| Platform | Support |
|----------|---------|
| linux/amd64 | Full |
| linux/arm64 | Full |

## Image Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable release |
| `x.y.z` | Specific version |
| `x.y` | Latest patch of minor version |
| `edge` | Latest development build |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the LGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

phpbu itself is created by [Sebastian Feldmann](https://github.com/sebastianfeldmann) and licensed under the BSD-3-Clause license.

## Links

- [phpbu Documentation](https://phpbu.de/documentation.html)
- [phpbu GitHub](https://github.com/sebastianfeldmann/phpbu)
- [Docker Hub](https://hub.docker.com/r/sebastianfeldmann/phpbu)
- [GitHub Container Registry](https://ghcr.io/sebastianfeldmann/phpbu)
