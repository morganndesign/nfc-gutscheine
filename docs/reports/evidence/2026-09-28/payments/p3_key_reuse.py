"""P3: re-using an idempotency key with a different payload (redeem, reload, transfer)."""
import uuid
from lib import *

card = issue(5000)
cid = card["id"]
K = "reuse-" + uuid.uuid4().hex

pr("redeem 10.00 key K", summary(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 1000}, key=K)))
pr("redeem 10.00 key K again (true retry)", summary(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 1000}, key=K)))
pr("redeem 25.00 key K (different amount)", summary(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": 2500}, key=K)))
pr("reload 10.00 key K (different operation)", summary(call("POST", f"/cards/{cid}/reload", OWNER, {"amount": 1000}, key=K)))
other = issue(5000)
pr("redeem 10.00 key K on ANOTHER card", summary(call("POST", f"/cards/{other['id']}/redeem", OWNER, {"amount": 1000}, key=K)))
pr("ledger card1", check_card(cid)[0])

# ---- transfer
src = issue(5000); dst = issue(1000)
T = "xfer-" + uuid.uuid4().hex
r1 = call("POST", f"/cards/{src['id']}/transfer", OWNER, {"target_card_id": dst["id"], "amount": 1000}, key=T)
pr("transfer 10.00 src->dst key T", {"http": r1["status"], "replayed": r1["json"].get("replayed"),
    "src_bal": r1["json"]["data"]["source"]["balance"], "dst_bal": r1["json"]["data"]["target"]["balance"],
    "tx_amounts": [t["amount"] for t in r1["json"]["data"]["transactions"]]})
for body, label in [({"target_card_id": dst["id"], "amount": 4000}, "same key T, amount 40.00"),
                    ({"target_card_id": dst["id"]}, "same key T, amount omitted (= full balance)"),
                    ({"target_card_id": issue(1000)["id"], "amount": 1000}, "same key T, DIFFERENT target")]:
    r = call("POST", f"/cards/{src['id']}/transfer", OWNER, body, key=T)
    j = r["json"]
    out = {"http": r["status"], "code": j.get("code"), "replayed": j.get("replayed")}
    if r["status"] < 300:
        out.update(src_bal=j["data"]["source"]["balance"], dst_bal=j["data"]["target"]["balance"],
                   tx_amounts=[t["amount"] for t in j["data"]["transactions"]])
    pr(f"transfer replay: {label}", out)
pr("ledger src", check_card(src["id"])[0])
pr("ledger dst", check_card(dst["id"])[0])
