"""B4: redeploy (api/worker/scheduler recreated, as Coolify does for a new commit) while 10 terminals redeem."""
import time, uuid, threading, collections, json
from ilib import *
W = json.load(open("/tmp/audit2/infra/waiters_all.json"))
ids = issue_many(10, 100000); res = []; lk = threading.Lock(); stop = time.time() + 75
def term(i):
    while time.time() < stop:
        k = str(uuid.uuid4()); r = call("POST", f"/cards/{ids[i]}/redeem", W[i], {"amount": 50}, key=k, device=f"deployterm-{i:04d}-abcdef", timeout=60)
        with lk: res.append({**r, "key": k})
        time.sleep(0.5)
th = [threading.Thread(target=term, args=(i,)) for i in range(10)]; t0 = time.time(); [t.start() for t in th]
time.sleep(10); td = time.time()
print(sh("/tmp/audit2/infra/dc.sh up -d --force-recreate api worker scheduler 2>&1 | tail -3"))
print(f"recreate command finished after {time.time()-td:.1f}s")
[t.join() for t in th]
bad = [r for r in res if r["status"] not in (200, 201)]
print("responses:", dict(collections.Counter((r["status"], r["code"]) for r in res)))
if bad:
    a = min(r["t"] for r in bad); b = max(r["t"] + r["ms"]/1000 for r in bad)
    print(f"outage window: +{a-t0:.1f}s .. +{b-t0:.1f}s = {b-a:.1f}s (deploy started +{td-t0:.1f}s)")
    booked = {x["k"] for x in q("select idempotency_key k from gift_card_transactions where idempotency_key is not null and created_at > now() - interval 10 minute")}
    print("errors that were nevertheless booked:", sum(1 for r in bad if r["key"] in booked))
