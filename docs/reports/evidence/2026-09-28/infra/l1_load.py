"""L1: waiter terminals doing scan (QR) + redeem, plus dashboard readers, at rising concurrency.
Records p50/p95/p99 per endpoint, throughput, errors and container memory (docker stats every 2 s)."""
import json, time, uuid, threading, collections, subprocess, sys
from ilib import *
W = json.load(open("/tmp/audit2/infra/waiters_all.json"))
STAGES = [int(x) for x in (sys.argv[1] if len(sys.argv) > 1 else "10,30,60").split(",")]
DUR = 45; THINK = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
ids = issue_many(240, 100000)
tok = {r["id"]: r["public_token"] for r in q("select id, public_token from gift_cards where id in (%s)" % ",".join(["%s"]*len(ids)), ids)}
mem = collections.defaultdict(float); stopmem = False
def memwatch():
    while not stopmem:
        out = subprocess.run("docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}'", shell=True, capture_output=True, text=True).stdout
        for line in out.splitlines():
            if "gcpaudit" not in line: continue
            n, used = line.split()[0], line.split()[1]
            v = float(used[:-3]) * (1024 if used.endswith("GiB") else 1 if used.endswith("MiB") else 1/1024)
            mem[n] = max(mem[n], v)
threading.Thread(target=memwatch, daemon=True).start()
for n in STAGES:
    res = collections.defaultdict(list); errs = collections.Counter(); lk = threading.Lock(); stop = time.time() + DUR
    def term(i):
        dev = f"loadterm-{i:04d}-abcdef"; c = ids[i % len(ids)]
        while time.time() < stop:
            r1 = call("POST", "/scan", W[i], {"method": "qr", "token": tok[c]}, device=dev, timeout=60)
            r2 = call("POST", f"/cards/{c}/redeem", W[i], {"amount": 50}, key=str(uuid.uuid4()), device=dev, timeout=60)
            with lk:
                res["scan"].append(r1["ms"]); res["redeem"].append(r2["ms"])
                for nm, r in (("scan", r1), ("redeem", r2)):
                    if r["status"] not in (200, 201): errs[(nm, r["status"], r["code"])] += 1
            time.sleep(THINK)
    def dash(i):
        t = [OWNER, MANAGER][i % 2]; dev = f"loaddash-{i:04d}-abcdef"
        while time.time() < stop:
            for path in ("/dashboard/stats", "/cards?per_page=25", "/dashboard/activity"):
                r = call("GET", path, t, device=dev, timeout=60)
                with lk:
                    res["dash " + path.split("?")[0]].append(r["ms"])
                    if r["status"] != 200: errs[("dash", r["status"], r["code"])] += 1
            time.sleep(2)
    th = [threading.Thread(target=term, args=(i,)) for i in range(n)] + [threading.Thread(target=dash, args=(i,)) for i in range(4)]
    t0 = time.time(); [t.start() for t in th]; [t.join() for t in th]; el = time.time() - t0
    total = sum(len(v) for v in res.values())
    print(f"=== {n} terminals + 4 dashboard users, think {THINK}s, {el:.0f}s: {total} requests = {total/el:.1f} req/s, redeems {len(res['redeem'])/el:.1f}/s")
    for k, v in res.items(): print(f"   {k:22s} n={len(v):5d} p50={pct(v,50)} p95={pct(v,95)} p99={pct(v,99)} max={round(max(v))} ms")
    print("   errors:", dict(errs) or "none")
stopmem = True; time.sleep(3)
print("peak memory MiB:", {k.replace('gcpaudit-', '').replace('-1', ''): round(v) for k, v in sorted(mem.items())}, "sum", round(sum(mem.values())))
print("invariant:", invariant())
