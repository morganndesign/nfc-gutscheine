#!/bin/sh
# Nightly logical backup of the MySQL database (run via cron: docker compose --profile backup run --rm backup).
# Keeps 14 days locally; sync ./backups to Hetzner Storage Box / S3 for off-site copies.
set -eu
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILE="/backups/giftcard_pro_${STAMP}.sql.gz"
mysqldump --single-transaction --quick --routines --triggers \
  -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" "${DB_DATABASE}" | gzip -9 > "${FILE}"
find /backups -name 'giftcard_pro_*.sql.gz' -mtime +14 -delete
echo "Backup written: ${FILE}"
