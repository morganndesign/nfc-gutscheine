"""F2: Redis stopped while the restaurant is working. What do terminals, the dashboard and /up see; how long
do requests hang; does anything recover by itself; are queued jobs kept?"""
import time, uuid, json, collections
from ilib import *
DEV = "redis-probe-terminal-01"
cards = issue_many(6, 50000)
def probe(label):
    out = {}
    out["redeem"] = call("POST", f"/cards/{cards[0]}/redeem", WAITERS[0], {"amount": 100}, key=str(uuid.uuid4()), device=DEV, timeout=60)
    out["card_get"] = call("GET", f"/cards/{cards[1]}", WAITERS[0], device=DEV, timeout=60)
    out["dashboard"] = call("GET", "/dashboard/summary", OWNER, device="redis-probe-owner-0001", timeout=60)
    t0 = time.time()
    try:
        r = requests.get("http://127.0.0.1:8080/up", timeout=60); up = (r.status_code, round((time.time()-t0)*1000))
    except Exception as e: up = (0, type(e).__name__)
    print(f"--- {label}")
    for k, r in out.items(): print(f"  {k:10s} http={r['status']} code={r['code']} {r['ms']:.0f} ms {str(r['json'])[:110] if r['status']>=400 or r['status']==0 else ''}")
    print(f"  /up       {up}")
    return out
probe("baseline")
queued_before = sh("docker exec gcpaudit-redis-1 sh -c 'redis-cli --no-auth-warning -a \"$REDIS_PASSWORD\" dbsize'")
print("redis dbsize before:", queued_before)
print(sh("docker stop gcpaudit-redis-1"))
time.sleep(2)
down = probe("redis STOPPED")
key = str(uuid.uuid4())
r = call("POST", f"/cards/{cards[2]}/redeem", WAITERS[1], {"amount": 700}, key=key, device=DEV, timeout=60)
booked = q("select count(*) n from gift_card_transactions where idempotency_key=%s", (key,))[0]["n"]
print(f"redeem during outage: http={r['status']} -> ledger rows for its key: {booked}")
time.sleep(20)
print("containers during outage:", sh("docker ps -a --filter name=gcpaudit --format '{{.Names}} {{.Status}}' | sort"))
print("worker log tail:", sh("docker logs --tail 3 gcpaudit-worker-1 2>&1 | cut -c1-200"))
print(sh("docker start gcpaudit-redis-1"))
time.sleep(8)
probe("redis STARTED again (no other action)")
print("redis dbsize after:", sh("docker exec gcpaudit-redis-1 sh -c 'redis-cli --no-auth-warning -a \"$REDIS_PASSWORD\" dbsize'"))
time.sleep(30)
print("containers 30s later:", sh("docker ps -a --filter name=gcpaudit --format '{{.Names}} {{.Status}}' | sort"))
