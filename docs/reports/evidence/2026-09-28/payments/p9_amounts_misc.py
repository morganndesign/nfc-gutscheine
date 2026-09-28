"""P9: amount edge cases, tenant isolation of money endpoints, missing/invalid idempotency keys, currency lock."""
import json
import subprocess
import uuid
import requests
from lib import *

card = issue(5000); cid = card["id"]


def raw_redeem(raw_body, key=None):
    h = {"Accept": "application/json", "Content-Type": "application/json", "Authorization": f"Bearer {OWNER}",
         "X-Device-Id": "audit-p9", "Idempotency-Key": key or str(uuid.uuid4())}
    r = requests.post(f"{API}/cards/{cid}/redeem", headers=h, data=raw_body, timeout=30)
    j = r.json()
    tx = (j.get("data") or {}).get("transaction") or {}
    return r.status_code, j.get("code"), tx.get("amount"), ((j.get("errors") or {}).get("amount") or [None])[0]


cases = ['{"amount": "10.005"}', '{"amount": 10.005}', '{"amount": 10.5}', '{"amount": 10.0}', '{"amount": "100"}', '{"amount": " 100"}',
         '{"amount": "1e2"}', '{"amount": 1e2}', '{"amount": 0}', '{"amount": -100}', '{"amount": "-100"}', '{"amount": 100000001}',
         '{"amount": 9223372036854775808}', '{"amount": true}', '{"amount": [100]}', '{"amount": "0x64"}', '{"amount": null}', '{}']
rows = []
for c in cases:
    rows.append((c, *raw_redeem(c)))
print(f"{'body':<40} http code                     booked  validation-msg")
for c, s, code, amt, msg in rows:
    print(f"{c:<40} {s:<4} {str(code):<25} {str(amt):<7} {msg}")
chk, txs = check_card(cid)
print("ledger after amount probes:", chk, [(t["type"], t["amount"]) for t in txs])

# idempotency header validation
for k in [None, "short", "has:colon-123", "x" * 97, "ok-key-" + uuid.uuid4().hex]:
    h = {"Accept": "application/json", "Content-Type": "application/json", "Authorization": f"Bearer {OWNER}", "X-Device-Id": "audit-p9"}
    if k is not None:
        h["Idempotency-Key"] = k
    r = requests.post(f"{API}/cards/{cid}/redeem", headers=h, data='{"amount": 1}', timeout=30)
    print(f"Idempotency-Key={str(k)[:20]!r:<24} -> {r.status_code} {r.json().get('code')}")

# tenant isolation on money paths (tenant B owner acting on tenant A card / transaction)
print("\ntenant B redeem on A card ->", summary(call("POST", f"/cards/{cid}/redeem", OWNER_B, {"amount": 100}, key=str(uuid.uuid4())))["http"])
print("tenant B reload on A card ->", summary(call("POST", f"/cards/{cid}/reload", OWNER_B, {"amount": 100}, key=str(uuid.uuid4())))["http"])
print("tenant B reverse A tx ->", call("POST", f"/transactions/{txs[-1]['id']}/reverse", OWNER_B, {"reason": "cross tenant"})["status"])
b_card = issue(5000, token=OWNER_B)
r = call("POST", f"/cards/{cid}/transfer", OWNER, {"target_card_number": b_card["card_number"], "amount": 100}, key=str(uuid.uuid4()))
print("A transfer to tenant-B card by number ->", r["status"], r["json"].get("code"))
r = call("POST", f"/cards/{cid}/transfer", OWNER, {"target_card_id": b_card["id"], "amount": 100}, key=str(uuid.uuid4()))
print("A transfer to tenant-B card by id ->", r["status"], r["json"].get("code"))
# same idempotency key in two tenants is independent
K = "shared-" + uuid.uuid4().hex
print("same key tenant A ->", summary(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 100}, key=K))["http"],
      " tenant B ->", summary(call("POST", f"/cards/{b_card['id']}/redeem", OWNER_B, {"amount": 100}, key=K))["http"])
print("ledger A:", check_card(cid)[0]["balance_ok"], " ledger B:", check_card(b_card["id"])[0]["balance_ok"])

# full-balance-only restaurant: partial refused; max_single_redemption enforced
call("PUT", "/settings/cards", OWNER, {"allow_partial_redemption": False, "max_single_redemption": 3000})
c2 = issue(5000)
print("\nallow_partial=false, redeem 10.00 of 50.00 ->", summary(call("POST", f"/cards/{c2['id']}/redeem", OWNER, {"amount": 1000}, key=str(uuid.uuid4())))["code"])
print("max_single_redemption=30.00, redeem 50.00 (full) ->", summary(call("POST", f"/cards/{c2['id']}/redeem", OWNER, {"amount": 5000}, key=str(uuid.uuid4())))["code"])
print("... but transfer 50.00 to another card (manager/owner path) ->", call("POST", f"/cards/{c2['id']}/transfer", OWNER, {"target_card_id": issue(1000)["id"]}, key=str(uuid.uuid4()))["status"])
call("PUT", "/settings/cards", OWNER, {"allow_partial_redemption": True, "max_single_redemption": None})
