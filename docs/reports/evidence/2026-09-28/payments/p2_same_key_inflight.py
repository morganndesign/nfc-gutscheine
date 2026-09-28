"""P2: the SAME idempotency key sent twice while the first request is still in flight.

The first request is made deterministically slow by holding the card row lock from a separate MySQL
session (SELECT ... FOR UPDATE). Request #1 is sent, then 0.5 s later the "retry" #2 with the same key
and body; after 3 s the lock is released.
"""
import threading
import time
import uuid
from lib import *


def scenario(label, value, amount):
    card = issue(value)
    cid = card["id"]
    key = "retry-" + uuid.uuid4().hex
    holder = db()
    holder.autocommit(False)
    cur = holder.cursor()
    cur.execute("START TRANSACTION")
    cur.execute("SELECT id, balance FROM gift_cards WHERE id=%s FOR UPDATE", (cid,))
    print(f"\n##### {label}: card {cid} balance {value}, redeem {amount} twice with key {key}")
    print("[lock] card row locked by external session")

    results = {}

    def fire(n):
        results[n] = call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": amount, "reference": "table-7"}, key=key)

    t1 = threading.Thread(target=fire, args=(1,)); t1.start()
    time.sleep(0.5)
    t2 = threading.Thread(target=fire, args=(2,)); t2.start()
    time.sleep(3)
    holder.commit(); holder.close()
    print("[lock] released")
    t1.join(); t2.join()
    for n in (1, 2):
        s = summary(results[n])
        print(f"request #{n}: {s}")
        if results[n]["status"] >= 400:
            print(f"   body: {results[n]['json']}")
    chk, rows = check_card(cid)
    print("ledger:", chk)
    for r in rows:
        print(f"  {r['type']:<11} {r['amount']:>6} {r['balance_before']:>6}->{r['balance_after']:<6} key={r['idempotency_key']}")
    # what a third, later retry (after both finished) gets:
    s3 = summary(call("POST", f"/cards/{cid}/redeem", OWNER, {"amount": amount, "reference": "table-7"}, key=key))
    print(f"request #3 (late retry, same key): {s3}")


scenario("A full-balance redeem", 5000, 5000)
scenario("B partial redeem, balance sufficient for two", 5000, 2000)
scenario("C redeem > half balance (second booking would be insufficient)", 5000, 3000)
