import { test } from "node:test"
import assert from "node:assert/strict"
import { isUncertainOutcome } from "./outcome.ts"

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
