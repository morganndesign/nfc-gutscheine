"""P5: concurrent reload + redeem + reverse on one card; the same transaction reversed concurrently.
P8: reversal can push the balance above max_card_balance; issue ignores max_card_balance."""
import collections
import uuid
from lib import *


def txid(r):
    return r["json"]["data"]["transaction"]["id"]


# ---------------- P5
card = issue(5000); cid = card["id"]
R1 = txid(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 1000}, key=str(uuid.uuid4())))
L1 = txid(call("POST", f"/cards/{cid}/reload", OWNER, {"amount": 1000}, key=str(uuid.uuid4())))
print("setup: balance after redeem 10 + reload 10 =", check_card(cid)[0]["card_balance"])
fns = []
fns += [lambda: ("reload 5", call("POST", f"/cards/{cid}/reload", OWNER, {"amount": 500}, key=str(uuid.uuid4()))) for _ in range(5)]
fns += [lambda: ("redeem 5", call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 500}, key=str(uuid.uuid4()))) for _ in range(5)]
fns += [lambda: ("reverse R1(redeem)", call("POST", f"/transactions/{R1}/reverse", OWNER, {"reason": "audit double reverse"})) for _ in range(5)]
fns += [lambda: ("reverse L1(reload)", call("POST", f"/transactions/{L1}/reverse", MANAGER, {"reason": "audit double reverse"})) for _ in range(5)]
res = parallel(fns)
pr("P5 mixed race (op http code) -> count", dict(collections.Counter(f"{op} {r['status']} {(r['json'] or {}).get('code')}" for op, r in res)))
chk, rows = check_card(cid)
pr("P5 ledger", chk)
for r in rows:
    print(f"  {r['type']:<11} {r['amount']:>6} {r['balance_before']:>6}->{r['balance_after']:<6} reversed_at={r['reversed_at']}")
print("reversal rows per original:", q("SELECT related_transaction_id, COUNT(*) n FROM gift_card_transactions WHERE type='reversal' AND gift_card_id=%s GROUP BY related_transaction_id", (cid,)))
print("reverse a reversal:", summary(call("POST", f"/transactions/{q('SELECT id FROM gift_card_transactions WHERE type=%s AND gift_card_id=%s LIMIT 1', ('reversal', cid))[0]['id']}/reverse", OWNER, {"reason": "reverse the reversal"})))

# ---------------- P8a reversal above max_card_balance (200000)
settings = call("GET", "/settings")["json"]["data"]["settings"]
print("\nP8 settings: max_card_value", settings["max_card_value"], "max_card_balance", settings["max_card_balance"])
c = issue(100000); c_id = c["id"]
call("POST", f"/cards/{c_id}/reload", OWNER, {"amount": 100000}, key=str(uuid.uuid4()))
Rbig = txid(call("POST", f"/cards/{c_id}/redeem", OWNER, {"amount": 50000}, key=str(uuid.uuid4())))
print("reload back to max:", summary(call("POST", f"/cards/{c_id}/reload", OWNER, {"amount": 50000}, key=str(uuid.uuid4()))))
print("reload 0.01 more (control):", summary(call("POST", f"/cards/{c_id}/reload", OWNER, {"amount": 1}, key=str(uuid.uuid4()))))
rv = call("POST", f"/transactions/{Rbig}/reverse", OWNER, {"reason": "audit P8 reversal"})
print("reverse the 500.00 redemption:", rv["status"], rv["json"].get("code"), "balance_after", (rv["json"].get("data") or {}).get("balance_after"))
print("card row:", q("SELECT balance, status FROM gift_cards WHERE id=%s", (c_id,)), "max_card_balance=200000", check_card(c_id)[0])

# ---------------- P8b issue ignores max_card_balance (config inconsistency accepted by settings API)
r = call("PUT", "/settings/cards", OWNER, {"max_card_value": 500000, "max_card_balance": 200000})
print("\nPUT settings/cards max_card_value=500000 > max_card_balance=200000 ->", r["status"])
r = call("PUT", "/settings/cards", OWNER, {"min_card_value": 900000})
print("PUT settings/cards min_card_value=900000 (> max_card_value) ->", r["status"])
call("PUT", "/settings/cards", OWNER, {"min_card_value": 500})
big = call("POST", "/cards", OWNER, {"value": 450000})
print("issue 4500.00 with max_card_balance 2000.00 ->", big["status"], (big["json"].get("data") or {}).get("balance"))
if big["status"] == 201:
    print("reload 1.00 on that card ->", summary(call("POST", f"/cards/{big['json']['data']['id']}/reload", OWNER, {"amount": 100}, key=str(uuid.uuid4()))))
call("PUT", "/settings/cards", OWNER, {"max_card_value": 100000, "max_card_balance": 200000})
print("settings restored")
