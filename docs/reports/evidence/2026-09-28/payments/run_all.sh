#!/usr/bin/env bash
# Re-runs the whole payment-integrity audit. Repo is never modified.
set -euo pipefail
cd "$(dirname "$0")"; . ./env.sh
B=/home/claude/GiftCardPro/backend
docker rm -f audit-mysql-pay >/dev/null 2>&1 || true
docker run -d --name audit-mysql-pay -p 3307:3306 -e MYSQL_DATABASE=gcp -e MYSQL_USER=gcp -e MYSQL_PASSWORD=gcp -e MYSQL_ROOT_PASSWORD=root \
  mysql:8.4 --transaction-isolation=READ-COMMITTED --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
until docker exec audit-mysql-pay mysqladmin -ugcp -pgcp ping 2>/dev/null | grep -q alive; do sleep 2; done; sleep 3
(cd $B && php artisan migrate:fresh --seed --force)
(cd $B && php artisan tinker --execute="require '/tmp/audit2/payments/mint_tokens.php';")
# NOTE: --no-reload is required, otherwise artisan serve ignores PHP_CLI_SERVER_WORKERS (single worker = no concurrency)
(cd $B && setsid nohup php artisan serve --port=8100 --no-reload > server.log 2>&1 < /dev/null &) ; sleep 3
pip show pymysql >/dev/null 2>&1 || pip install pymysql
for s in p1_concurrent_redeem p2_same_key_inflight p2b_same_key_transfer_reload p3_key_reuse p4_transfer_races p5_p8_reverse p6_p7_expiry p9_amounts_misc; do
  python3 $s.py 2>&1 | tee $s.run.log
done
mysql -h127.0.0.1 -P3307 -ugcp -pgcp gcp < invariant.sql | tee invariant.run.log
# Fix verification: fixcheck/ is an out-of-repo copy with fix.diff applied (serve it on :8101 and re-run with API=http://127.0.0.1:8101/api/v1)
