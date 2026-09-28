"""Helpers for infra failure-injection and load probes against the production-like stack (gateway :8080)."""
import json, subprocess, threading, time, uuid
import pymysql, requests

API = "http://127.0.0.1:8080/api/v1"
TOK = json.load(open("/tmp/audit2/infra/tokens.json"))
OWNER = TOK[0]["token"]; MANAGER = TOK[1]["token"]
WAITERS = json.load(open("/tmp/audit2/infra/waiters.json"))
DC = "/tmp/audit2/infra/dc.sh"

def db():
    return pymysql.connect(host="127.0.0.1", port=33306, user="root", password="TestRootPassword456", database="giftcard_pro", autocommit=True, connect_timeout=3)

def q(sql, args=None):
    c = db()
    try:
        with c.cursor(pymysql.cursors.DictCursor) as cur:
            cur.execute(sql, args); return cur.fetchall()
    finally:
        c.close()

_s = threading.local()
def sess():
    if not hasattr(_s, "s"):
        _s.s = requests.Session()
    return _s.s

def call(method, path, token, body=None, key=None, device=None, timeout=90):
    h = {"Accept": "application/json", "Content-Type": "application/json", "Authorization": f"Bearer {token}",
         "X-Device-Id": device or ("infra-" + uuid.uuid4().hex[:10])}
    if key: h["Idempotency-Key"] = key
    t0 = time.time()
    try:
        r = sess().request(method, API + path, headers=h, data=json.dumps(body) if body is not None else None, timeout=timeout)
        try: j = r.json()
        except Exception: j = {"raw": r.text[:200]}
        return {"status": r.status_code, "code": j.get("code") if isinstance(j, dict) else None, "json": j, "ms": (time.time()-t0)*1000, "t": t0}
    except Exception as e:
        return {"status": 0, "code": type(e).__name__, "json": {"err": str(e)[:200]}, "ms": (time.time()-t0)*1000, "t": t0}

def issue_many(n, value, token=OWNER, workers=8):
    from concurrent.futures import ThreadPoolExecutor
    toks = [OWNER, MANAGER]
    def one(i):
        for _ in range(5):
            r = call("POST", "/cards", toks[i % 2], {"value": value}, key=str(uuid.uuid4()))
            if r["status"] == 201: return r["json"]["data"]["id"]
            time.sleep(2)
        raise RuntimeError(r)
    with ThreadPoolExecutor(workers) as ex:
        return list(ex.map(one, range(n)))

def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

def pct(xs, p):
    xs = sorted(xs)
    return round(xs[min(len(xs)-1, int(len(xs)*p/100))], 1) if xs else None

INVARIANT = open("/tmp/audit2/payments/invariant.sql").read()
def invariant():
    c = db(); out = []
    with c.cursor() as cur:
        cur.execute(INVARIANT); out = cur.fetchall()
    c.close(); return out
