"""P4: opposing transfers A->B / B->A in parallel + concurrent transfer and redeem on the same card."""
import collections
import uuid
from lib import *

ROUNDS = 5
all_codes = collections.Counter()
for rnd in range(ROUNDS):
    A = issue(10000); B = issue(10000)
    fns = []
    for i in range(10):
        fns.append(lambda: ("A->B", call("POST", f"/cards/{A['id']}/transfer", OWNER, {"target_card_id": B["id"], "amount": 100}, key=str(uuid.uuid4()))))
        fns.append(lambda: ("B->A", call("POST", f"/cards/{B['id']}/transfer", OWNER, {"target_card_id": A["id"], "amount": 300}, key=str(uuid.uuid4()))))
    for i in range(4):
        fns.append(lambda: ("redeem A", call("POST", f"/cards/{A['id']}/redeem", OWNER, {"amount": 50}, key=str(uuid.uuid4()))))
        fns.append(lambda: ("redeem B", call("POST", f"/cards/{B['id']}/redeem", OWNER, {"amount": 70}, key=str(uuid.uuid4()))))
    res = parallel(fns)
    codes = collections.Counter(f"{op} {r['status']} {(r['json'] or {}).get('code')}" for op, r in res)
    all_codes.update(codes)
    ca, _ = check_card(A["id"]); cb, _ = check_card(B["id"])
    ok_redeem = sum(50 if op == "redeem A" else 70 for op, r in res if op.startswith("redeem") and r["status"] == 201)
    total = ca["card_balance"] + cb["card_balance"]
    print(f"round {rnd}: {dict(codes)}")
    print(f"   A={ca['card_balance']} (ledger {ca['ledger_sum']}, chain {ca['chain_ok']})  B={cb['card_balance']} (ledger {cb['ledger_sum']}, chain {cb['chain_ok']})"
          f"  A+B={total}  expected 20000-{ok_redeem}={20000-ok_redeem}  conserved={total == 20000-ok_redeem}")
    fivexx = [r for op, r in res if r["status"] >= 500]
    for r in fivexx[:3]:
        print("   5xx:", r["json"])
pr("all rounds (op http code) -> count", dict(all_codes))

# Drain race: 5 "transfer full balance" (amount omitted) X->Y racing 5 redeems of 20.00 on X
X = issue(10000); Y = issue(1000)
fns = [lambda: ("xfer-all X->Y", call("POST", f"/cards/{X['id']}/transfer", OWNER, {"target_card_id": Y["id"]}, key=str(uuid.uuid4()))) for _ in range(5)]
fns += [lambda: ("redeem X", call("POST", f"/cards/{X['id']}/redeem", OWNER, {"amount": 2000}, key=str(uuid.uuid4()))) for _ in range(5)]
res = parallel(fns)
pr("drain race (op http code) -> count", dict(collections.Counter(f"{op} {r['status']} {(r['json'] or {}).get('code')}" for op, r in res)))
cx, _ = check_card(X["id"]); cy, _ = check_card(Y["id"])
redeemed = sum(2000 for op, r in res if op == "redeem X" and r["status"] == 201)
pr("drain race ledgers", {"X": cx, "Y": cy, "X+Y": cx["card_balance"] + cy["card_balance"], "expected": 11000 - redeemed})
