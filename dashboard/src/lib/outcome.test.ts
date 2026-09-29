import { test } from "node:test"
import assert from "node:assert/strict"
import {
  PENDING_KEY_TTL_MS,
  RELOAD_CODES,
  REDEMPTION_CODES,
  SALE_CODES,
  forgetPendingKey,
  isUncertainOutcome,
  pendingKey,
  rememberPendingKey,
} from "./outcome.ts"

test("a definitive refusal is certain: nothing was booked", () => {
  for (const status of [400, 401, 403, 404, 409, 422, 429]) assert.equal(isUncertainOutcome({ status }), false, String(status))
})

test("server errors and timeouts are uncertain", () => {
  for (const status of [408, 500, 502, 503, 504]) assert.equal(isUncertainOutcome({ status }), true, String(status))
})

test("no answer at all is uncertain", () => {
  assert.equal(isUncertainOutcome(new TypeError("Failed to fetch")), true)
  assert.equal(isUncertainOutcome(new DOMException("aborted", "AbortError")), true)
})

test("after an unanswered request only the operation's own codes are definitive", () => {
  const earlier = { unanswered: true, finalCodes: REDEMPTION_CODES }
  for (const [status, code] of [
    [401, "UNAUTHENTICATED"],
    [403, "FORBIDDEN"],
    [429, "TOO_MANY_REQUESTS"],
    [404, "NOT_FOUND"],
    [409, "IDEMPOTENCY_CONFLICT"],
  ] as const) {
    assert.equal(isUncertainOutcome({ status, code }, earlier), true, `${status} ${code}`)
  }
  assert.equal(isUncertainOutcome({ status: 422 }, earlier), true, "no code")
  assert.equal(isUncertainOutcome({ status: 422, code: "INSUFFICIENT_BALANCE" }, earlier), false)
  assert.equal(isUncertainOutcome({ status: 422, code: "PRESENTMENT_INVALID" }, earlier), false)
  assert.equal(isUncertainOutcome({ status: 422, code: "INVALID_AMOUNT" }, { unanswered: true, finalCodes: SALE_CODES }), false)
  assert.equal(isUncertainOutcome({ status: 403, code: "COMPLIMENTARY_NOT_ALLOWED" }, { unanswered: true, finalCodes: SALE_CODES }), false)
  assert.equal(isUncertainOutcome({ status: 422, code: "VOUCHER_BLOCKED" }, { unanswered: true, finalCodes: RELOAD_CODES }), false)
})

test("unanswered keys are kept in the tab for a while", () => {
  const store = new Map<string, string>()
  const g = globalThis as unknown as { window?: unknown }
  const previous = g.window
  g.window = {
    sessionStorage: {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
    },
  }
  try {
    assert.equal(pendingKey("sale:5000:cash:"), null)
    rememberPendingKey("sale:5000:cash:", "key-1", 1_000)
    assert.equal(pendingKey("sale:5000:cash:", 1_000 + PENDING_KEY_TTL_MS), "key-1")
    assert.equal(pendingKey("sale:5000:card_terminal:", 1_000), null)
    assert.equal(pendingKey("sale:5000:cash:", 1_001 + PENDING_KEY_TTL_MS), null, "expired")
    rememberPendingKey("redeem:v:100", "key-2", 1_000)
    forgetPendingKey("redeem:v:100")
    assert.equal(pendingKey("redeem:v:100", 1_000), null)
  } finally {
    g.window = previous
  }
})

test("without storage the helpers do nothing", () => {
  assert.equal(pendingKey("x"), null)
  rememberPendingKey("x", "k")
  forgetPendingKey("x")
})
