// End-to-end test of the native waiter app API (GiftCard Waiter) against a running stack.
// Plays the app's calls exactly as docs/design/waiter-app/09-flutter-handoff.md §9 specifies them:
// start-up config → token sign-in → /auth/me → scan the voucher QR (presentment) → redeem (+ idempotent replay)
// → device checks → sign-out.
//
//   API_URL=http://localhost:8000 OWNER_EMAIL=owner@bellavista.test WAITER_EMAIL=waiter@bellavista.test node waiter-api.mjs

import assert from "node:assert/strict"
import { randomUUID } from "node:crypto"

const API = (process.env.API_URL ?? "http://localhost:8000").replace(/\/$/, "")
const ORIGIN = process.env.WEB_ORIGIN ?? "http://localhost:3000"
const PASSWORD = process.env.PASSWORD ?? "Password123!"
const OWNER = process.env.OWNER_EMAIL ?? "owner@bellavista.test"
const WAITER = process.env.WAITER_EMAIL ?? "waiter@bellavista.test"

const DEVICE = randomUUID()
const USER_AGENT = "GiftCardWaiter/1.0.0 (Android 14; E2E Pixel)"

let step = 0
async function check(name, fn) {
  step += 1
  const started = performance.now()
  await fn()
  console.log(`✓ ${String(step).padStart(2)} ${name} (${Math.round(performance.now() - started)} ms)`)
}

/** Owner: cookie session like the web dashboard. */
function createSession() {
  const jar = new Map()
  const cookieHeader = () => [...jar].map(([k, v]) => `${k}=${v}`).join("; ")
  const store = (res) => {
    for (const line of res.headers.getSetCookie()) {
      const [pair] = line.split(";")
      const index = pair.indexOf("=")
      jar.set(pair.slice(0, index), pair.slice(index + 1))
    }
  }

  return async function request(method, path, body, extraHeaders = {}) {
    const xsrf = jar.get("XSRF-TOKEN")
    const res = await fetch(`${API}${path}`, {
      method,
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        Origin: ORIGIN,
        Referer: `${ORIGIN}/`,
        Cookie: cookieHeader(),
        ...(xsrf ? { "X-XSRF-TOKEN": decodeURIComponent(xsrf) } : {}),
        ...extraHeaders,
      },
      body: body ? JSON.stringify(body) : undefined,
    })
    store(res)
    return res
  }
}

/** Waiter: the native app's request rules (bearer token, device id, request id). */
async function app(method, path, { token, body, device = DEVICE, headers = {} } = {}) {
  const res = await fetch(`${API}/api/v1${path}`, {
    method,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "User-Agent": USER_AGENT,
      "X-Device-Id": device,
      "X-Request-Id": randomUUID(),
      "Accept-Language": "de",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  const json = await res.json().catch(() => null)
  return { status: res.status, json, headers: res.headers }
}

const owner = createSession()
let token
let voucher
let qr
let deviceId

await check("owner signs in to the dashboard", async () => {
  await owner("GET", "/sanctum/csrf-cookie")
  const res = await owner("POST", "/api/v1/auth/login", { email: OWNER, password: PASSWORD })
  assert.equal(res.status, 200, `owner login failed: ${res.status}`)
})

await check("owner sells a € 50 printable voucher, paid in cash", async () => {
  const res = await owner("POST", "/api/v1/vouchers", { value: 5000, form: "printable", payment: { method: "cash" }, recipient_name: "E2E waiter app" }, { "Idempotency-Key": randomUUID() })
  assert.equal(res.status, 201)
  const json = await res.json()
  voucher = json.data
  qr = json.printable.payload
  assert.match(qr, /^GCPV1\.[A-Za-z0-9_-]{43}$/)
})

await check("app reads start-up config", async () => {
  const res = await app("GET", "/app/config?platform=android&version=1.0.0")
  assert.equal(res.status, 200)
  assert.equal(res.json.data.update_required, false)
  assert.match(res.headers.get("cache-control") ?? "", /max-age=60/)
})

await check("waiter signs in with a device-bound token", async () => {
  const res = await app("POST", "/auth/token", {
    body: { email: WAITER, password: PASSWORD, device_id: DEVICE, device_name: "E2E Pixel", platform: "android" },
  })
  assert.equal(res.status, 201, JSON.stringify(res.json))
  token = res.json.data.token
  assert.deepEqual(res.json.data.user.permissions, ["vouchers.redeem"])
})

await check("/auth/me returns the restaurant settings the app needs", async () => {
  const res = await app("GET", "/auth/me", { token })
  assert.equal(res.status, 200)
  const settings = res.json.data.restaurant.settings
  for (const key of ["max_debit_per_transaction", "brand_color", "allow_partial_redemption"]) assert.ok(key in settings, key)
  assert.ok(res.json.data.restaurant.locale)
})

await check("a typed voucher number is not a credential", async () => {
  const res = await app("POST", "/presentments", { token, body: { purpose: "spend", method: "printable_qr", credential: voucher.voucher_number } })
  assert.equal(res.status, 422)
  assert.equal(res.json.code, "MEDIUM_NOT_RECOGNIZED")
})

let presentment
await check("scanning the QR creates a single-use presentment", async () => {
  const res = await app("POST", "/presentments", { token, body: { purpose: "spend", method: "printable_qr", credential: qr } })
  assert.equal(res.status, 201, JSON.stringify(res.json))
  assert.equal(res.json.data.voucher.balance, 5000)
  presentment = res.json.data.id
})

await check("redeem € 12,50 is booked once, a retry with the same key is replayed", async () => {
  const key = randomUUID()
  const body = { amount: 1250, presentment_id: presentment }
  const started = performance.now()
  const first = await app("POST", `/vouchers/${voucher.id}/redemptions`, { token, body, headers: { "Idempotency-Key": key } })
  const elapsed = performance.now() - started
  assert.equal(first.status, 201, JSON.stringify(first.json))
  assert.equal(first.json.data.voucher.balance, 3750)
  assert.ok(elapsed < 2000, `redeem took ${elapsed} ms`)

  const replay = await app("POST", `/vouchers/${voucher.id}/redemptions`, { token, body, headers: { "Idempotency-Key": key } })
  assert.equal(replay.status, 200)
  assert.equal(replay.json.replayed, true)
  assert.equal(replay.json.data.voucher.balance, 3750)
})

await check("the used presentment cannot pay again", async () => {
  const res = await app("POST", `/vouchers/${voucher.id}/redemptions`, { token, body: { amount: 100, presentment_id: presentment }, headers: { "Idempotency-Key": randomUUID() } })
  assert.equal(res.status, 422)
  assert.equal(res.json.code, "PRESENTMENT_INVALID")
})

await check("the token cannot reach management endpoints", async () => {
  const res = await app("GET", "/vouchers", { token })
  assert.equal(res.status, 403)
})

await check("the token is useless on another phone", async () => {
  const res = await app("GET", "/auth/me", { token, device: randomUUID() })
  assert.equal(res.status, 401)
})

await check("owner revokes the phone → DEVICE_REVOKED, restore → works again", async () => {
  const list = await owner("GET", "/api/v1/devices?per_page=100")
  const devices = (await list.json()).data
  deviceId = devices.find((d) => d.name === "E2E Pixel")?.id
  assert.ok(deviceId, "device not registered")

  assert.equal((await owner("POST", `/api/v1/devices/${deviceId}/revoke`)).status, 200)
  const revoked = await app("GET", "/auth/me", { token })
  assert.equal(revoked.status, 403)
  assert.equal(revoked.json.code, "DEVICE_REVOKED")

  assert.equal((await owner("POST", `/api/v1/devices/${deviceId}/restore`)).status, 200)
  assert.equal((await app("GET", "/auth/me", { token })).status, 200)
})

await check("sign-out revokes the token", async () => {
  assert.equal((await app("POST", "/auth/logout", { token })).status, 200)
  assert.equal((await app("GET", "/auth/me", { token })).status, 401)
})

console.log(`\nWaiter app API: ${step} steps passed.`)
