"""P6: default validity + nightly expiry write-off and its irreversibility. P7: Manager can expire a card early."""
import datetime as dt
import subprocess
import uuid
from lib import *

ENV = open("/tmp/audit2/payments/env.sh").read().split("export ", 1)[1].strip()


def probes(cid, label):
    exp_tx = q("SELECT id FROM gift_card_transactions WHERE gift_card_id=%s AND type='expiration'", (cid,))
    out = {}
    if exp_tx:
        out["reverse expiration tx (owner)"] = summary(call("POST", f"/transactions/{exp_tx[0]['id']}/reverse", OWNER, {"reason": "customer complaint"}))
    red = q("SELECT id FROM gift_card_transactions WHERE gift_card_id=%s AND type='redemption' LIMIT 1", (cid,))
    if red:
        out["reverse earlier redemption (owner)"] = summary(call("POST", f"/transactions/{red[0]['id']}/reverse", OWNER, {"reason": "customer complaint"}))
    far = (dt.date.today() + dt.timedelta(days=400)).isoformat()
    out["PATCH expires_at +400d (owner)"] = summary(call("PATCH", f"/cards/{cid}", OWNER, {"expires_at": far}))
    out["PATCH expires_at null (owner)"] = summary(call("PATCH", f"/cards/{cid}", OWNER, {"expires_at": None}))
    out["unblock (owner)"] = summary(call("POST", f"/cards/{cid}/unblock", OWNER, {}))
    out["activate (owner)"] = summary(call("POST", f"/cards/{cid}/activate", OWNER, {}))
    out["reload 10.00 (owner)"] = summary(call("POST", f"/cards/{cid}/reload", OWNER, {"amount": 1000}, key=str(uuid.uuid4())))
    out["redeem 1.00 (owner)"] = summary(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 100}, key=str(uuid.uuid4())))
    other = issue(1000)
    out["transfer to new card (owner)"] = {"http": (r := call("POST", f"/cards/{cid}/transfer", OWNER, {"target_card_id": other["id"]}, key=str(uuid.uuid4())))["status"], "code": r["json"].get("code")}
    out["replace (owner)"] = {"http": (r := call("POST", f"/cards/{cid}/replace", OWNER, {"reason": "restore balance"}))["status"], "code": r["json"].get("code")}
    out["expire again (owner)"] = summary(call("POST", f"/cards/{cid}/expire", OWNER, {}))
    pr(f"{label}: recovery attempts", {k: (v["http"], v["code"]) for k, v in out.items()})


# ---------------- P6 default validity
now_utc = dt.datetime.now(dt.timezone.utc)
card = issue(5000)
cid = card["id"]
row = q("SELECT expires_at, created_at FROM gift_cards WHERE id=%s", (cid,))[0]
pr("P6 issue without expires_at", {"api_expires_at": card["expires_at"], "db_expires_at": row["expires_at"], "created_at": row["created_at"],
                                    "months_diff": (row["expires_at"].year - row["created_at"].year) * 12 + row["expires_at"].month - row["created_at"].month})
none_card = call("POST", "/cards", OWNER, {"value": 5000, "expires_at": None})["json"]["data"]
pr("P6 issue with explicit expires_at=null", {"expires_at": none_card["expires_at"]})

call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 1500}, key=str(uuid.uuid4()))
blocked = issue(3000)
call("POST", f"/cards/{blocked['id']}/block", OWNER, {"reason": "reported lost, replacement pending"})
# time travel: last valid day ended yesterday
past = (now_utc - dt.timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")
q("UPDATE gift_cards SET expires_at=%s WHERE id IN (%s,%s)", (past, cid, blocked["id"]))
print("\nexpires_at set to", past, "for", cid, "and blocked card", blocked["id"])
print("redeem BEFORE nightly job:", summary(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 100}, key=str(uuid.uuid4()))))
cmd = f"cd /home/claude/GiftCardPro/backend && env {ENV} php artisan giftcards:expire"
print("$ php artisan giftcards:expire\n" + subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout)
for c in (cid, blocked["id"]):
    chk, rows = check_card(c)
    print("card", c, chk)
    for r in rows:
        print(f"  {r['type']:<11} {r['amount']:>6} {r['balance_before']:>6}->{r['balance_after']:<6}")
probes(cid, "P6 nightly-expired card")

# ---------------- P7 manager expires a card valid for ~3 years
card7 = issue(8000)
print("\nP7 card", card7["id"], "expires_at", card7["expires_at"], "balance", card7["balance"])
r = call("POST", f"/cards/{card7['id']}/expire", MANAGER, {"reason": "manager pressed expire"})
print("P7 manager POST /cards/{id}/expire ->", r["status"], "status", r["json"].get("data", {}).get("status"), "balance", r["json"].get("data", {}).get("balance"))
chk, rows = check_card(card7["id"])
print("ledger", chk, [(x["type"], x["amount"]) for x in rows])
print("audit:", q("SELECT a.action, u.email FROM audit_logs a LEFT JOIN users u ON u.id=a.user_id WHERE a.auditable_id=%s AND a.action='gift_card.expired'", (card7["id"],)))
probes(card7["id"], "P7 manager-expired card")
