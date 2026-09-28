"""F3: SMTP server accepts TCP but never answers. Measures invitation / password reset / platform onboarding
latency and outcome, php-fpm worker occupation, and the effect on concurrent redemptions."""
import time, uuid, threading, json
from ilib import *
ts = lambda: time.strftime("%H:%M:%S")
def timed(label, fn):
    t0 = time.time(); r = fn(); print(f"[{ts()}] {label}: http={r['status']} code={r['code']} after {(time.time()-t0):.1f}s  {str(r['json'])[:140]}"); return r

# fpm saturation: 26 concurrent invitations (owner), then redemptions while they hang
res = []
def inv(i):
    res.append(call("POST", "/users", OWNER, {"name": f"T{i}", "email": f"tp{i}-{uuid.uuid4().hex[:4]}@bellavista.test", "role": "waiter"}, device="tarpit-owner-device-01", timeout=400))
cards = issue_many(3, 50000)
th = [threading.Thread(target=inv, args=(i,)) for i in range(26)]; [t.start() for t in th]
time.sleep(4)
print(f"[{ts()}] php-fpm processes busy:", sh("docker exec gcpaudit-api-1 sh -c 'ps -o stat,args | grep -c \"php-fpm: pool\"'"))
for i in range(3):
    timed(f"redeem #{i+1} during saturation", lambda: call("POST", f"/cards/{cards[i]}/redeem", WAITERS[2], {"amount": 100}, key=str(uuid.uuid4()), device="tarpit-waiter-device-1", timeout=400))
[t.join() for t in th]
import collections
print("26 invitations:", collections.Counter((r["status"], r["code"]) for r in res), "max", round(max(r["ms"] for r in res)/1000,1), "s")
