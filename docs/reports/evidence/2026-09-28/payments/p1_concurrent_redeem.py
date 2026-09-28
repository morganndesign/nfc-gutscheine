"""P1: 20 parallel redeems of 10.00 (different idempotency keys) on a 50.00 card."""
import collections
import uuid
from lib import *

card = issue(5000)
cid = card["id"]
pr("card issued", {"id": cid, "balance": card["balance"], "status": card["status"]})

res = parallel([lambda: call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 1000}, key=str(uuid.uuid4())) for _ in range(20)])
sums = [summary(r) for r in res]
counter = collections.Counter((s["http"], s["code"]) for s in sums)
pr("result distribution (http, code) -> count", {f"{k[0]} {k[1]}": v for k, v in counter.items()})
pr("balances returned by the 201s", sorted([s["balance"] for s in sums if s["http"] == 201], reverse=True))
pr("latency ms min/max", [min(s["ms"] for s in sums), max(s["ms"] for s in sums)])
chk, rows = check_card(cid)
pr("ledger check", chk)
for r in rows:
    print(f"  {r['type']:<12} {r['amount']:>7} {r['balance_before']:>7} -> {r['balance_after']:>7}")

# Round 2: 20 parallel redeems of 3.00 on a 50.00 card — velocity limit is 10/h/card: are more than 10 booked?
card2 = issue(5000)
res = parallel([lambda: call("POST", f"/cards/{card2['id']}/redeem", OWNER, {"amount": 300}, key=str(uuid.uuid4())) for _ in range(20)])
counter = collections.Counter((r["status"], (r["json"] or {}).get("code")) for r in res)
pr("velocity probe: 20 parallel 3.00 redeems (limit 10/h) -> (http, code) count", {f"{k[0]} {k[1]}": v for k, v in counter.items()})
chk2, _ = check_card(card2["id"])
pr("velocity probe ledger", chk2)
