#!/bin/bash
# B1: run the backup service's exact dump command now, restore it into a brand-new MySQL, verify the ledger.
set -u
B=gcpaudit-backup-1
echo "== dump (same command as the backup service)"
start=$(date +%s.%N)
docker exec $B sh -c 'set -eu -o pipefail; f=/backups/giftcard_pro_drill.sql.gz; mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --quick --routines --triggers --no-tablespaces "$MYSQL_DATABASE" 2>/dev/null | gzip -9 > $f.part && mv $f.part $f && ls -la $f'
echo "dump seconds: $(echo "$(date +%s.%N) - $start" | bc)"
docker cp $B:/backups/giftcard_pro_drill.sql.gz /tmp/audit2/infra/drill.sql.gz
echo "== restore into a fresh mysql:8.4"
docker rm -f restoreprobe >/dev/null 2>&1
docker run -d --name restoreprobe -e MYSQL_ROOT_PASSWORD=r -e MYSQL_DATABASE=giftcard_pro mysql:8.4 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci >/dev/null
for i in $(seq 1 90); do docker exec restoreprobe mysql -uroot -pr -h127.0.0.1 -e 'select 1' >/dev/null 2>&1 && break; sleep 2; done
start=$(date +%s.%N)
gunzip -c /tmp/audit2/infra/drill.sql.gz | docker exec -i restoreprobe mysql -uroot -pr giftcard_pro 2>&1 | grep -v Warning
echo "restore seconds: $(echo "$(date +%s.%N) - $start" | bc)"
Q='select (select count(*) from gift_cards) cards, (select count(*) from gift_card_transactions) tx, (select sum(balance) from gift_cards) balances, (select count(*) from users) users, (select count(*) from migrations) migrations'
echo "source : $(docker exec gcpaudit-mysql-1 mysql -uroot -pTestRootPassword456 giftcard_pro -N -e "$Q" 2>/dev/null)"
echo "restore: $(docker exec restoreprobe mysql -uroot -pr giftcard_pro -N -e "$Q" 2>/dev/null)"
echo "restore invariant:"; docker exec -i restoreprobe mysql -uroot -pr giftcard_pro -N < /tmp/audit2/payments/invariant.sql 2>/dev/null
