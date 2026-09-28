"""Shared helpers for the GiftCard Pro payment-integrity probes (API on :8100, MySQL on :3307)."""
import json
import os
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

import pymysql
import requests

API = os.environ.get("API", "http://127.0.0.1:8100/api/v1")
TOKENS = json.load(open("/tmp/audit2/payments/tokens.json"))
OWNER = TOKENS["owner@bellavista.test"]
MANAGER = TOKENS["manager@bellavista.test"]
OWNER_B = TOKENS["owner@goldenerhirsch.test"]


def db():
    return pymysql.connect(host="127.0.0.1", port=3307, user="gcp", password="gcp", database="gcp", autocommit=True)


def q(sql, args=None):
    c = db()
    try:
        with c.cursor(pymysql.cursors.DictCursor) as cur:
            cur.execute(sql, args)
            return cur.fetchall()
    finally:
        c.close()


def call(method, path, token=OWNER, body=None, key=None, device=None):
    h = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
        # a fresh device id per request keeps the per-terminal throttle (90/min) out of the measurements
        "X-Device-Id": device or ("audit-" + uuid.uuid4().hex[:12]),
    }
    if key is not None:
        h["Idempotency-Key"] = key
    t0 = time.time()
    r = requests.request(method, API + path, headers=h, data=json.dumps(body) if body is not None else None, timeout=120)
    try:
        j = r.json()
    except Exception:
        j = {"raw": r.text[:300]}
    return {"status": r.status_code, "json": j, "ms": int((time.time() - t0) * 1000)}


def summary(res):
    j = res["json"] or {}
    tx = (j.get("data") or {}).get("transaction") if isinstance(j.get("data"), dict) else None
    card = (j.get("data") or {}).get("card") if isinstance(j.get("data"), dict) else None
    return {
        "http": res["status"],
        "code": j.get("code"),
        "message": (j.get("message") or "")[:90] or None,
        "replayed": j.get("replayed"),
        "tx_id": tx and tx.get("id"),
        "tx_amount": tx and tx.get("amount"),
        "balance": card and card.get("balance"),
        "ms": res["ms"],
    }


def issue(value=5000, token=OWNER, **extra):
    body = {"value": value, **extra}
    r = call("POST", "/cards", token, body)
    assert r["status"] == 201, r
    return r["json"]["data"]


def parallel(fns):
    """Run callables simultaneously (released together by a barrier)."""
    barrier = threading.Barrier(len(fns))

    def wrap(fn):
        barrier.wait()
        return fn()

    with ThreadPoolExecutor(max_workers=len(fns)) as ex:
        futs = [ex.submit(wrap, f) for f in fns]
        return [f.result() for f in futs]


INVARIANT_SQL = """
SELECT c.id, c.card_number, c.status, c.balance,
       COALESCE(SUM(t.amount),0) AS ledger_sum,
       c.total_loaded, c.total_redeemed
FROM gift_cards c LEFT JOIN gift_card_transactions t ON t.gift_card_id = c.id
{where}
GROUP BY c.id HAVING c.balance <> ledger_sum
"""

CHAIN_SQL = """
SELECT t.gift_card_id, t.id, t.type, t.amount, t.balance_before, t.balance_after,
       LAG(t.balance_after) OVER (PARTITION BY t.gift_card_id ORDER BY t.created_at, t.id) AS prev_after
FROM gift_card_transactions t {where}
"""


def check_card(card_id):
    """Returns (balance_ok, chain_ok, rows) for one card."""
    card = q("SELECT balance,status,total_loaded,total_redeemed FROM gift_cards WHERE id=%s", (card_id,))[0]
    rows = q("SELECT id,type,amount,balance_before,balance_after,idempotency_key,reversed_at,created_at "
             "FROM gift_card_transactions WHERE gift_card_id=%s ORDER BY created_at,id", (card_id,))
    s = sum(r["amount"] for r in rows)
    chain_ok = True
    prev = 0
    for r in rows:
        if r["balance_before"] != prev or r["balance_after"] != r["balance_before"] + r["amount"]:
            chain_ok = False
        prev = r["balance_after"]
    return {"card_balance": card["balance"], "status": card["status"], "ledger_sum": int(s),
            "balance_ok": card["balance"] == s, "chain_ok": chain_ok and prev == card["balance"], "tx_count": len(rows)}, rows


def pr(title, obj=None):
    print(f"\n=== {title}")
    if obj is not None:
        print(json.dumps(obj, indent=1, default=str))
