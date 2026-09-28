#!/bin/bash
# B2: the backup loop body from docker-compose.coolify.yml, run once while MySQL is unreachable, with a /backups
# volume whose newest good dump is 15 days old (backups have been failing silently for 15 days).
docker rm -f b2probe >/dev/null 2>&1
docker run --rm --name b2probe --network gcpaudit_default -e MYSQL_ROOT_PASSWORD=wrong-after-rotation -e MYSQL_DATABASE=giftcard_pro -e BACKUP_KEEP_DAYS=14 --entrypoint sh mysql:8.4 -c '
set -eu -o pipefail
for d in 15 16 17 18 19 20; do touch -d "$d days ago" /backups/giftcard_pro_old$d.sql.gz 2>/dev/null || { mkdir -p /backups; touch -d "$d days ago" /backups/giftcard_pro_old$d.sql.gz; }; done
echo "before: $(ls /backups | wc -l) dumps"; ls -la --time-style=+%F /backups | tail -n +4
# ---- verbatim loop body ----
file="/backups/giftcard_pro_$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
if mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --quick --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip -9 > "$file.part"; then
  mv "$file.part" "$file"; echo "Backup written: $file"
else
  rm -f "$file.part"; echo "Backup FAILED" >&2
fi
find /backups -name "giftcard_pro_*.sql.gz" -mtime +"$BACKUP_KEEP_DAYS" -delete
# ---- end ----
echo "after: $(ls /backups | wc -l) dumps"; echo "container still running the loop: yes (no exit, no alert)"'
