"""P2b: same root cause as P2 on the other money endpoints (transfer full balance, reload up to max_card_balance)."""
import threading
import time
import uuid
from lib import *


def inflight_twice(lock_ids, method_path, body, label):
    key = "retry-" + uuid.uuid4().hex
    holder = db(); holder.autocommit(False); cur = holder.cursor()
    cur.execute("START TRANSACTION")
    for i in sorted(lock_ids):
        cur.execute("SELECT id FROM gift_cards WHERE id=%s FOR UPDATE", (i,))
    res = {}

    def fire(n):
        res[n] = call("POST", method_path, OWNER, body, key=key)

    t1 = threading.Thread(target=fire, args=(1,)); t1.start(); time.sleep(0.5)
    t2 = threading.Thread(target=fire, args=(2,)); t2.start(); time.sleep(3)
    holder.commit(); holder.close(); t1.join(); t2.join()
    print(f"\n##### {label} (key {key})")
    for n in (1, 2):
        j = res[n]["json"]
        print(f"request #{n}: http {res[n]['status']} code={j.get('code')} replayed={j.get('replayed')} context={j.get('context')}")
    r3 = call("POST", method_path, OWNER, body, key=key)
    print(f"request #3 (late retry): http {r3['status']} replayed={r3['json'].get('replayed')}")


src = issue(5000); dst = issue(1000)
inflight_twice([src["id"], dst["id"]], f"/cards/{src['id']}/transfer", {"target_card_id": dst["id"]}, "transfer FULL balance src->dst, retried in flight")
print("ledgers:", check_card(src["id"])[0], check_card(dst["id"])[0])

c = issue(100000)
call("POST", f"/cards/{c['id']}/reload", OWNER, {"amount": 50000}, key=str(uuid.uuid4()))  # balance 1500.00, max 2000.00
inflight_twice([c["id"]], f"/cards/{c['id']}/reload", {"amount": 50000}, "reload 500.00 to reach max_card_balance, retried in flight")
print("ledger:", check_card(c["id"])[0])
