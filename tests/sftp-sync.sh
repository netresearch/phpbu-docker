#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Netresearch DTT GmbH
#
# End-to-end test of the SFTP sync in the full image: phpbu backs up a
# directory and uploads the archive to a throwaway SFTP server, and the test
# reads the file back from that server.
#
# phpbu's SFTP sync needs phpseclib 2.x (it calls phpseclib\Net\SFTP). With
# phpseclib 3 or 4 installed the class is missing, phpbu reports
# 'phpseclib not installed' and the sync fails while the backup itself passes.
#
# Usage: tests/sftp-sync.sh <image>

set -euo pipefail

IMAGE="${1:?usage: tests/sftp-sync.sh <image>}"
# atmoz/sftp:alpine, pinned by digest.
SFTP_IMAGE="atmoz/sftp:alpine@sha256:c5fb9e4beb8b7054a4c0b65c5e11df47cc20da95ad6002e88aecff62bab06372"
RUN_ID="phpbu-sftp-test-$$"
WORK="$(mktemp -d)"

cleanup() {
  docker rm -f "$RUN_ID-server" >/dev/null 2>&1 || true
  docker network rm "$RUN_ID" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

docker network create "$RUN_ID" >/dev/null
# User "backup", password "secret", UID 1001, with an upload directory.
docker run -d --name "$RUN_ID-server" --network "$RUN_ID" "$SFTP_IMAGE" \
  backup:secret:1001::upload >/dev/null

# Wait for sshd to accept connections (at most 30 seconds).
for _ in $(seq 1 30); do
  if docker exec "$RUN_ID-server" sh -c 'nc -z 127.0.0.1 22' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

cat > "$WORK/backup.json" <<EOF
{
  "verbose": true,
  "backups": [
    {
      "name": "sftp-sync-test",
      "source": {"type": "tar", "options": {"path": "/app/vendor/phpbu"}},
      "target": {"dirname": "/tmp/backups", "filename": "sftp-test.tar"},
      "syncs": [
        {
          "type": "sftp",
          "options": {
            "host": "$RUN_ID-server",
            "user": "backup",
            "password": "secret",
            "path": "upload"
          }
        }
      ]
    }
  ]
}
EOF
chmod 644 "$WORK/backup.json"

status=0
docker run --rm --network "$RUN_ID" \
  -v "$WORK/backup.json:/config/backup.json:ro" \
  "$IMAGE" --configuration=/config/backup.json > "$WORK/phpbu.log" 2>&1 || status=$?
cat "$WORK/phpbu.log"

if [[ "$status" -ne 0 ]]; then
  echo "::error::phpbu exited with status $status"
  exit 1
fi
if ! docker exec "$RUN_ID-server" test -s /home/backup/upload/sftp-test.tar; then
  echo "::error::sftp-test.tar did not arrive on the SFTP server"
  exit 1
fi
echo "OK: sftp-test.tar arrived on the SFTP server"
