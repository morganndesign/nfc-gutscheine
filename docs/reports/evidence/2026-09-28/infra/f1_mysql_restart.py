"""F1: MySQL restart (graceful or SIGKILL) while 30 terminals redeem. Checks ledger integrity, what the
client was told, and whether a same-key retry after recovery replays (no second booking) or books."""
import sys, threading, time, uuid, collections, json
from ilib import *

MODE = sys.argv[1] if len(sys.argv) > 1 else "restart"   # restart | kill
DUR, INJECT_AT = 50, 12
cards = issue_many(300, 50000)
print(f"[{MODE}] issued {len(cards)} cards")
results, lock = [], threading.Lock()
stop = time.time() + DUR

def terminal(i):
    my = cards[i*10:(i+1)*10]; n = 0; dev = f"term-{i}"
    while time.time() < stop:
        cid = my[n % 10]; n += 1
        if n > 90: break                      # stay under the 10 redemptions/h/card velocity limit
        k = str(uuid.uuid4())
        r = call("POST", f"/cards/{cid}/redeem", WAITERS[i], {"amount": 100}, key=k, device=dev, timeout=30)
        with lock: results.append({"key": k, "card": cid, "tok": i, **{x: r[x] for x in ("status", "code", "ms", "t")}})
        time.sleep(0.2)

th = [threading.Thread(target=terminal, args=(i,)) for i in range(30)]
t0 = time.time(); [t.start() for t in th]
time.sleep(INJECT_AT)
ti = time.time()
if MODE == "kill":
    pid = sh("docker inspect -f '{{.State.Pid}}' gcpaudit-mysql-1"); print("kill -9 mysqld host pid", pid, sh(f"kill -9 {pid}; echo rc=$?"))
    time.sleep(1); print("state after kill:", sh("docker inspect -f '{{.State.Status}} restarts={{.RestartCount}}' gcpaudit-mysql-1"))
else:
    print(sh("docker restart -t 10 gcpaudit-mysql-1"))
print(f"injected at +{ti-t0:.1f}s, docker returned at +{time.time()-t0:.1f}s")
[t.join() for t in th]

# wait for recovery
for _ in range(300):
    try: q("select 1"); break
    except Exception: time.sleep(1)
print("mysql state:", sh("docker inspect -f '{{.State.Status}} restarts={{.RestartCount}} health={{.State.Health.Status}}' gcpaudit-mysql-1"))
time.sleep(3)

by = collections.Counter((r["status"], r["code"]) for r in results)
print("responses:", json.dumps({f"{a} {b}": v for (a, b), v in sorted(by.items(), key=lambda x: -x[1])}))
bad = [r for r in results if r["status"] not in (200, 201)]
if bad:
    b0 = min(r["t"] for r in bad) - t0; b1 = max(r["t"] + r["ms"]/1000 for r in bad) - t0
    import collections as C
    hist = C.Counter(int(r["t"]-t0) for r in bad); print("errors per second (+s: n):", dict(sorted(hist.items())))
    print(f"error window: +{b0:.1f}s .. +{b1:.1f}s ({b1-b0:.1f}s), max latency {max(r['ms'] for r in results):.0f} ms")

# ledger truth per key
rows = q("select idempotency_key k, count(*) n from gift_card_transactions where type='redemption' and idempotency_key is not null group by idempotency_key")
booked = {r["k"]: r["n"] for r in rows}
dups = [k for k, n in booked.items() if n > 1]
ok_not_booked = [r for r in results if r["status"] in (200, 201) and r["key"] not in booked]
err_but_booked = [r for r in bad if r["key"] in booked]
print(f"keys with >1 booking: {len(dups)}; 200 but not booked: {len(ok_not_booked)}; error but BOOKED: {len(err_but_booked)} of {len(bad)} errors")
for r in err_but_booked[:5]: print("  error-but-booked:", r["status"], r["code"])

# retry every failed request with the SAME key after recovery (what a correct client must do)
retry = collections.Counter(); after_booked = 0
for r in bad:
    rr = call("POST", f"/cards/{r['card']}/redeem", WAITERS[r["tok"]], {"amount": 100}, key=r["key"], device=f"term-{r['tok']}")
    retry[(rr["status"], rr["code"], (rr["json"] or {}).get("replayed"))] += 1
print("same-key retry after recovery:", json.dumps({f"{a} {b} replayed={c}": v for (a, b, c), v in retry.items()}))
rows = q("select idempotency_key k, count(*) n from gift_card_transactions where type='redemption' and idempotency_key is not null group by idempotency_key having count(*)>1")
print("keys with >1 booking after retries:", len(rows))
print("invariant:", invariant())
